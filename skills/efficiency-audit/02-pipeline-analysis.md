---
name: efficiency-audit-pipeline-analysis
description: Sub-skill 2 of efficiency-audit. Statically analyze the user's training/inference/data pipeline code by READING IT (no profiling — too slow). Detect data-flow stages, byte-counts, and where time is likely spent. Compare against theoretical_limits.yaml from sub-skill 1 to flag saturation. Output analysis.html.
---

# Sub-skill 2 — Pipeline analysis (static, by reading code)

## Prerequisites

- `report/efficiency/theoretical_limits.yaml` (sub-skill 1 output). If missing, run sub-skill 1 first.
- Path to the user's entry-point script (e.g., `train.py`, `infer.py`, `process.py`).
- Knowledge of which framework: PyTorch / TensorFlow / JAX / plain NumPy. PyTorch patterns dominate; others use the same conceptual pipeline.

## Critical constraint (read this twice)

**DO NOT run the user's profiler.** Do NOT add `torch.profiler.profile(...)` or run `nsys profile` or `py-spy record`. Those take minutes to hours and add overhead that distorts the very thing you're trying to measure. The whole point of an *audit* is that it's fast: ceiling (sub-skill 1) + static demand estimate (this sub-skill) → red-alarm verdict in under a minute.

Use Grep + Read tools only. Estimate byte counts from tensor shapes the way a careful reviewer would on a whiteboard.

## What to look for

### Grep patterns (run these first)

```bash
# Data loading
grep -nE "DataLoader\(|num_workers=|pin_memory=|prefetch_factor=|persistent_workers=|drop_last=" <entry_script>

# GPU placement
grep -nE "\.to\(['\"]cuda|\.cuda\(\)|\.to\(device|\.to\(self\.device" <entry_script>

# Mixed precision / AMP
grep -nE "autocast|GradScaler|torch\.float16|bfloat16|amp" <entry_script>

# Distributed / multi-GPU
grep -nE "dist\.all_reduce|dist\.broadcast|DistributedDataParallel|DataParallel|FSDP" <entry_script>

# Per-step IO
grep -nE "torch\.save|np\.save|np\.savez|open\(.*['\"][wa]|pickle\.dump|\.write\(|imwrite|cv2\.imwrite" <entry_script>

# Step boundaries
grep -nE "optimizer\.step|loss\.backward|model\.eval|model\.train|accumulate_grad|gradient_accumulation_steps" <entry_script>

# Tensor shape hints
grep -nE "torch\.zeros|torch\.empty|torch\.randn|torch\.Tensor|shape=|\.reshape|\.view|\.permute" <entry_script>
```

Also `Read` the entry script and any imported `dataset.py` / `dataloader.py` / `model.py` to follow the dataflow.

### The 4-node data-flow graph

Build a graph with 4 nodes and the transfers between them:

```
[Disk]  --read-->  [CPU mem]  --H2D copy-->  [GPU mem]  --compute-->  [GPU compute]
                                                        <--D2H copy-- 
                                              [CPU mem]  --write-->  [Disk]
```

For each edge, compute the bytes per training step (or per inference step). Use tensor shapes from the code; if a shape is dynamic / unknown, mark `unknown — annotate` and continue.

**Worked example** (a simple image-classification training loop):

```python
# Dataset returns (img_tensor[3, 224, 224, float32], label[int64])
# Batch size 256, num_workers=4
# Model: ResNet-50 → ~25M params, FP32 forward+backward ~16 GFLOPs/sample
```

| Edge                        | Bytes per step                                               | Source                                              |
| --------------------------- | ------------------------------------------------------------ | --------------------------------------------------- |
| Disk → CPU (input batch)    | 256 × 3 × 224 × 224 × 4 B = 154 MB                           | dataset shape, batch_size                           |
| CPU → GPU (H2D)             | 154 MB                                                       | same tensor, after collate                          |
| GPU compute (forward+back)  | 256 × 16 GFLOPs × 3 (fwd+bwd+grad) = 12.3 TFLOP              | ResNet-50 reference                                 |
| GPU → CPU (loss scalar)     | 4 B                                                          | scalar                                              |
| CPU → Disk (checkpoint)     | 25M × 4 B × 2 (params + optim) = 200 MB **per save_every**   | model.state_dict()                                  |

### Comparing demand against ceiling

For each edge, divide its bytes-per-step by the relevant ceiling from `theoretical_limits.yaml`:

```
estimated_time_disk_read_s   = bytes_disk_read   / io.sequential_write_GB_s     (use read ≈ write for SSD; lower for HDD)
estimated_time_h2d_copy_s    = bytes_h2d_copy    / pcie_GB_s                    (PCIe Gen4 x16 ≈ 25 GB/s; NVLink ≈ 300+ GB/s)
estimated_time_gpu_compute_s = total_FLOPs       / (count × fp16_bf16_tflops × 1e12)   (if AMP), else fp32_tflops
estimated_time_disk_write_s  = bytes_written     / io.sequential_write_GB_s
```

The slowest stage is the likely bottleneck. If GPU compute time >> any IO time AND GPU utilization metric (from sub-skill 1) shows >= 70%, the code is GPU-bound and likely near-optimal. Otherwise red-alarm.

## Output: `report/efficiency/analysis.html`

Light theme; inline SVG only (no external JS, must render offline). Color palette:

| Element            | Hex     |
| ------------------ | ------- |
| Background         | #f8fafc |
| Body text          | #1e293b |
| Accent — GPU       | #3b82f6 |
| Accent — CPU       | #f59e0b |
| Accent — IO        | #10b981 |
| Accent — Network   | #8b5cf6 |

### Required sections

1. **Header**: machine summary from sub-skill 1 (5-line digest)
2. **Detected pipeline stages**: bullet list, one per node, with line ranges
3. **Data movement table**: bytes per step, the table above
4. **Theoretical ceiling vs estimated actual demand**: side-by-side bar chart (inline SVG) — one bar per resource showing % saturation
5. **Suspected bottleneck**: one line with verdict (`RED ALARM` or `GREEN: bottlenecked on <X>`)
6. **Confidence**: HIGH (all shapes known) / MEDIUM (some unknown shapes) / LOW (many unknowns — say so honestly)

### Skeleton HTML

```html
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Efficiency Audit — Pipeline Analysis</title>
<style>
body{background:#f8fafc;color:#1e293b;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;margin:2em auto;max-width:960px;padding:0 1em;line-height:1.5}
h1,h2{color:#1e293b}
.gpu{color:#3b82f6}.cpu{color:#f59e0b}.io{color:#10b981}.net{color:#8b5cf6}
table{border-collapse:collapse;width:100%;margin:1em 0}
th,td{border:1px solid #cbd5e1;padding:.5em;text-align:left}
th{background:#e2e8f0}
.bar{fill:#3b82f6}.bar-cpu{fill:#f59e0b}.bar-io{fill:#10b981}
.alarm{background:#fee2e2;color:#991b1b;padding:.5em 1em;border-left:4px solid #dc2626;font-weight:bold}
.green{background:#dcfce7;color:#166534;padding:.5em 1em;border-left:4px solid #16a34a;font-weight:bold}
</style></head><body>
<h1>Efficiency Audit — Pipeline Analysis</h1>
<!-- sections 1..6 here -->
</body></html>
```

### Saturation bar chart (inline SVG)

```html
<svg viewBox="0 0 600 200" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Resource saturation">
  <text x="0" y="20" font-size="14">GPU</text>
  <rect x="60" y="5"  width="<gpu_pct * 5>" height="20" class="bar"/>
  <text x="0" y="50" font-size="14">CPU</text>
  <rect x="60" y="35" width="<cpu_pct * 5>" height="20" class="bar-cpu"/>
  <text x="0" y="80" font-size="14">IO</text>
  <rect x="60" y="65" width="<io_pct * 5>" height="20" class="bar-io"/>
  <line x1="410" y1="0" x2="410" y2="100" stroke="#dc2626" stroke-dasharray="4 2"/>
  <text x="415" y="12" font-size="11" fill="#dc2626">70% threshold</text>
</svg>
```

The `<gpu_pct * 5>` placeholders are template substitutions — fill in the actual percentages (0..100 mapped to 0..500 px width).

## How to write the analysis (workflow)

1. `Grep` the entry script with the patterns above. Record line numbers.
2. `Read` the dataset / collate / model files referenced by the entry script.
3. Compute byte counts per step from the largest tensor shapes you can find. If a shape depends on runtime data, write `unknown — depends on <variable>` and use a representative value.
4. Pull the ceiling numbers from `theoretical_limits.yaml`.
5. Divide demand by ceiling → saturation percent.
6. Emit the HTML.
7. Print a one-line verdict to the chat.

## When to write `RED ALARM` vs `GREEN`

- **GREEN**: at least one of `gpu_saturation`, `cpu_saturation`, `io_saturation` ≥ 70%. Speedup is still possible (algorithmic), but no resource is sitting idle.
- **RED ALARM**: all three saturations < 70%. The code is provably wasting compute. Proceed to sub-skill 3.

## Done condition

`report/efficiency/analysis.html` exists, parses, contains all 6 required sections, and the verdict line is either RED or GREEN. Move on to sub-skill 3 if RED.
