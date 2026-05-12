---
name: efficiency-audit-bottleneck-reflection
description: Sub-skill 3 of efficiency-audit. After analysis.html shows a RED ALARM, enumerate at least 5 basic + 3 advanced optimization candidates, score each by estimated speedup / risk / effort, and emit strategies.md with the top 3 picks for experiment validation.
---

# Sub-skill 3 — Bottleneck reflection (two rounds of brainstorming)

## Prerequisites

- `report/efficiency/analysis.html` exists and the verdict is `RED ALARM` (or you're auditing a previously-green pipeline for further gains).
- You know which resource is the largest under-utilization gap from sub-skill 2.

## Why two rounds?

A single sweep tends to land on the user's pet optimization (whatever the agent saw last). Two rounds — basic first, advanced second — forces an exhaustive review of the easy stuff before reaching for esoteric kernels. Most production code wastes 5–10x on basics; reaching for `torch.compile` before fixing `num_workers=0` is malpractice.

## Round 1 — Basic candidates (≥ 5 required)

For each, list: **what**, **why it helps**, **estimated speedup**, **risk**, **implementation effort** (S/M/L), **test recipe**.

### B1. DataLoader concurrency

| Field           | Value                                                                                   |
| --------------- | --------------------------------------------------------------------------------------- |
| What            | Set `num_workers >= 4` (or `min(os.cpu_count(), 8)`), `persistent_workers=True`, `pin_memory=True`, `prefetch_factor=2`. |
| Why             | Default `num_workers=0` blocks the main process on data loading; workers parallelize disk reads + decode + augment. |
| Estimated speedup | 2–10x when IO-bound, 0% when not                                                       |
| Risk            | Low (some datasets break with workers > 0 due to fork-unsafe state)                     |
| Effort          | S                                                                                       |
| Test recipe     | Time one epoch with `num_workers=0` vs `num_workers=4`; compare wall time.              |

### B2. Mixed precision (AMP / BF16)

| What        | Wrap forward in `with torch.autocast(device_type='cuda', dtype=torch.bfloat16):`; use `GradScaler` for FP16, none for BF16. |
| Why         | Tensor-core math is 4–8x faster at FP16/BF16 than FP32 on A100/H100/4090. |
| Speedup     | 1.5–3x on training-bound workloads                                       |
| Risk        | Medium (numerical stability; BF16 safer than FP16)                       |
| Effort      | S                                                                        |
| Test recipe | Compare 100 training steps FP32 vs BF16; check loss curve & step time.   |

### B3. Output write batching

| What        | Replace per-sample `torch.save` / `np.save` in the inner loop with a buffered writer that flushes once per N steps (or once per epoch). |
| Why         | A small write of a few KB is dominated by filesystem overhead (~ms each); batching to MB-class writes uses the throughput from theoretical_limits. |
| Speedup     | 10–100x on the IO stage if hot                                          |
| Risk        | Low (crash safety: flush more often if mid-run failure is costly)       |
| Effort      | S/M                                                                     |
| Test recipe | Time 1000 writes individually vs in a single `np.savez`; compare.        |

### B4. Avoid redundant CPU↔GPU copies

| What        | Eliminate `.cpu()` and `.cuda()` calls inside the inner loop; keep tensors on-device once they arrive. |
| Why         | Each H2D/D2H copy is bound by PCIe (~25 GB/s) and stalls the launch queue. |
| Speedup     | 1.2–2x if hot                                                             |
| Risk        | Low (mostly cleanup)                                                      |
| Effort      | S                                                                         |
| Test recipe | Grep for `.cpu(` and `.cuda(` inside the loop; remove redundant ones; rerun. |

### B5. Single-load-broadcast for multi-GPU

| What        | If running on N GPUs and the dataset is small/static, load it once on rank 0 and `dist.broadcast` instead of having each rank read from disk independently. |
| Why         | N processes contending for the same disk → N× IO load with no benefit.  |
| Speedup     | up to N× on the load stage                                              |
| Risk        | Medium (memory pressure if data is large)                               |
| Effort      | M                                                                       |
| Test recipe | Time first-batch latency with naive multi-rank load vs broadcast.       |

### B6. Gradient accumulation tuning

| What        | If batch size is memory-bound and the model spends most time on backward, consider increasing per-GPU batch size + decreasing accumulation steps (or vice versa). |
| Why         | More steps per `optimizer.step()` amortize the optimizer cost.           |
| Speedup     | 1.1–1.5x                                                                 |
| Risk        | Low (mathematically equivalent when LR is scaled)                        |
| Effort      | S                                                                        |
| Test recipe | Sweep accumulation_steps ∈ {1, 4, 16}; compare throughput.               |

### B7. `drop_last=True` + correct epoch boundary

| What        | Use `drop_last=True` on DataLoader to keep all batches the same size; recompile-friendly. |
| Why         | A short last batch invalidates compiled kernels (re-trace).             |
| Speedup     | small (1.0–1.05x) but avoids hidden recompilation cost                  |
| Risk        | Low                                                                     |
| Effort      | S                                                                       |

### B8. `model.eval()` + `no_grad` in inference paths

| What        | Wrap inference with `with torch.no_grad():` and `model.eval()`.         |
| Why         | Disables autograd graph + bn/dropout — significant memory + step time win. |
| Speedup     | 1.3–2x on inference                                                     |
| Risk        | Low                                                                     |
| Effort      | S                                                                       |

Pick ≥ 5 of B1..B8 (or invent context-specific ones) that match the user's code. Skip ones that don't apply.

## Round 2 — Advanced candidates (≥ 3 required)

These require more engineering but unlock further speedups when Round 1 is exhausted.

### A1. Reduce total bytes moved (compute-then-aggregate-then-chunk)

| What        | If the loop does `for x in data: y = f(x); buf.append(y); aggregate(buf)` — restructure to compute `f(x)` in chunks and aggregate incrementally, freeing memory. |
| Why         | Cuts peak memory and the implied D2H/H2D ferrying.                       |
| Speedup     | 1.5–5x when memory is the bottleneck                                     |
| Risk        | Medium (algorithmic refactor; correctness must be re-verified)           |
| Effort      | M/L                                                                      |

### A2. Op fusion (`torch.compile`, FlashAttention, fused AdamW)

| What        | Wrap model with `torch.compile(model, mode='reduce-overhead')`; replace stock attention with FlashAttention; use `torch.optim.AdamW(..., fused=True)`. |
| Why         | Kernel launch overhead becomes meaningful below ~1 ms per kernel; fusion collapses dozens of tiny kernels into one. |
| Speedup     | 1.3–2x typical, sometimes more for attention-heavy models                |
| Risk        | Medium (compile may fail on dynamic shapes; FlashAttention requires recent SM ≥ 80) |
| Effort      | M                                                                        |
| Test recipe | Time 50 steps with vs without compile; ensure loss matches.              |

### A3. CPU↔GPU overlap via CUDA streams + async copies

| What        | Use `non_blocking=True` on `.to(device)`; issue prefetch on a separate `torch.cuda.Stream`. Combine with `pin_memory=True` on DataLoader. |
| Why         | Hides H2D copy latency behind compute.                                    |
| Speedup     | 1.1–1.4x                                                                  |
| Risk        | Medium (stream-sync bugs are notoriously subtle)                          |
| Effort      | M                                                                         |

### A4. Recomputation / activation checkpointing

| What        | Wrap blocks with `torch.utils.checkpoint.checkpoint(...)` to trade compute for memory. |
| Why         | Allows larger batch (better tensor-core utilization) at small compute cost. |
| Speedup     | 1.0–1.3x net (positive when memory was the bottleneck)                    |
| Risk        | Medium                                                                    |
| Effort      | M                                                                         |

### A5. Tensor / sequence parallelism

| What        | Shard parameters across GPUs (Megatron-style TP) or sequence dim (Ring-Attention). |
| Why         | Removes the all_reduce bottleneck that limits DDP scaling above ~8 GPUs. |
| Speedup     | depends — can be 1.5–3x on large models                                  |
| Risk        | High (significant code changes)                                          |
| Effort      | L                                                                        |

### A6. Quantization (INT8 / FP8)

| What        | Cast inference weights/activations to INT8 or FP8; calibrate scaling. |
| Why         | INT8 tensor-cores are 2x BF16 throughput on Hopper; memory bandwidth halved. |
| Speedup     | 1.5–2x on inference                                                  |
| Risk        | Medium-high (accuracy regression must be measured)                   |
| Effort      | M/L                                                                  |

### A7. Reduce all_reduce volume

| What        | Gradient bucketing, gradient compression (PowerSGD), or hierarchical all_reduce.  |
| Why         | Comm time grows with model size; reducing volume scales DDP further. |
| Speedup     | 1.1–1.3x on comm-bound multi-node training                           |
| Risk        | Medium (compression hurts convergence in some regimes)               |
| Effort      | M                                                                    |

Pick ≥ 3 of A1..A7 that match the user's code.

## Ranking and selection

Score each candidate using:

```
priority = estimated_speedup / (effort_score × risk_score)

where effort_score = {S: 1, M: 3, L: 9} and risk_score = {Low: 1, Medium: 2, High: 4}
```

Take the **top 3** by priority. These are the ones sub-skill 4 will validate.

## Output: `report/efficiency/strategies.md`

Format:

```markdown
# Bottleneck Reflection — strategies.md

## Round 1 (basic) candidates

### B1. DataLoader concurrency
- Speedup estimate: 2-10x
- Risk: Low
- Effort: S
- Priority score: ...
- Test recipe: ...

(... B2..B8 if applicable ...)

## Round 2 (advanced) candidates

### A1. Reduce bytes moved
(... full record ...)

## Top 3 for validation (sub-skill 4)

1. B1 (DataLoader concurrency) — priority N.NN
2. B2 (Mixed precision)        — priority N.NN
3. A2 (torch.compile)          — priority N.NN
```

## Done condition

`report/efficiency/strategies.md` exists, contains ≥ 5 basic + ≥ 3 advanced candidates, and ends with a numbered "Top 3 for validation" list. Move on to sub-skill 4.
