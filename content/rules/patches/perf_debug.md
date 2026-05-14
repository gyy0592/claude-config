---
id: P-003
created: 2026-05-14T00:00:00Z
source: human
scope: global
applies_to:
  state: [EXECUTE_LOOP, REFLECT]
  scenario: bug_perf
  triggers:
    - keyword: ["slow", "throughput", "latency", "tokens/sec", "MFU", "util", "throughput", "speedup", "benchmark"]
    - tool: Bash
      cmd_regex: "nvidia-smi|nsys|nvprof|py-spy|perf record|timeit"
priority: 100
status: active
---

## what

Require baseline measurement + one-variable-at-a-time + steady-state (not warmup) reading before declaring any perf delta.

## why

- L-018: a naive benchmark can show speedup < 1.0 even when the optimization is real; per-sample cost must exceed fork/IPC overhead, and the timing loop must run multi-epoch inside one process.
- W-002: silently disabling acceleration paths in pursuit of speed is forbidden; quantified before/after evidence is the only legitimate basis for perf changes.

## how

1. **Baseline first** — capture pre-change metric:
   - Workload definition (batch size, seq len, model size, dataset slice).
   - Hardware fixed (same node, same GPU id, same driver).
   - ≥ 3 trials; report median + min + max.
   - Warmup excluded: discard first N iterations (rule of thumb: N = max(5, 10% of total)).
2. **One variable at a time** — record under `[VAR=<name> from <old> to <new>]`.
3. **Steady-state, not warmup** — measure tokens/sec or it/sec over a window AFTER warmup, not from the first iteration.
4. **Per-sample cost sanity** — for parallel/dataloader speedups, confirm per-sample cost ≫ fork+IPC overhead (≥ 20 ms/`__getitem__`) AND run timing loop multi-epoch in one process.
5. **Report format**: `[PERF] <metric> baseline=X new=Y delta=±Z% (n=trials, hw=node/GPU)`.

## examples

DataLoader num_workers: baseline (workers=0) 12.3 it/s ± 0.4 → workers=4 35.1 it/s ± 1.1 → speedup 2.85x (n=5, GPU 0). NOT: "feels faster".
