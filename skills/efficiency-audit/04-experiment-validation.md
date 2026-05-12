---
name: efficiency-audit-experiment-validation
description: Sub-skill 4 of efficiency-audit. Validate the top 3 strategies from strategies.md with minimal before/after micro-benchmarks (median-of-5 with warmup). Save logs to report/efficiency/experiments/. If a strategy fails (no speedup or broken correctness), loop back to sub-skill 3 to pick the next candidate. Max 3 retries per strategy.
---

# Sub-skill 4 — Experiment validation (real numbers, not vibes)

## Prerequisites

- `report/efficiency/strategies.md` with a "Top 3 for validation" section.
- The user's entry script is runnable (small representative slice — one batch, one step, a single inference call).
- Python ≥ 3.8 with the user's environment (PyTorch / NumPy / whatever the user uses).

## Why median-of-5 with warmup

A single timing is noisy: first call pays JIT / kernel-compile / page-fault costs; OS context switches add jitter. Median-of-5 measurements with 2 warmup iterations dropped is the cheapest reliable estimator. **Mean is the wrong statistic** — one slow run blows up the average.

## Timing recipe (the canonical pattern)

```python
import time
import statistics

def time_block(fn, n_warmup=2, n_runs=5, sync=None):
    # warmup
    for _ in range(n_warmup):
        fn()
        if sync is not None: sync()
    # measured
    samples = []
    for _ in range(n_runs):
        t0 = time.perf_counter()
        fn()
        if sync is not None: sync()
        samples.append(time.perf_counter() - t0)
    return statistics.median(samples), samples
```

`sync` should be `torch.cuda.synchronize` when the work is on GPU; `None` for pure CPU work. Forgetting `torch.cuda.synchronize()` makes GPU timings garbage (kernel launches are async; you'd measure launch time, not execution time).

## How to run one validation

For each of the top 3 strategies from `strategies.md`:

1. Write a **minimal** script that runs the *same* small slice (one batch or one step) in two modes:
   - `before`: original code
   - `after`: code with the strategy applied
2. Use the timing recipe above on both.
3. Verify correctness: output tensors / loss values should match within tolerance (FP32: 1e-5, BF16/FP16: 1e-2).
4. Compute `speedup = before_median / after_median`.
5. Append a log to `report/efficiency/experiments/<strategy_name>.log`:

```text
strategy: B1 DataLoader concurrency
date: 2026-05-12 18:42 UTC
slice: one epoch on 1000-sample synthetic dataset

before: num_workers=0
  samples_s: [4.21, 4.18, 4.25, 4.20, 4.23]
  median_s : 4.21
after:  num_workers=4, persistent_workers=True
  samples_s: [1.18, 1.16, 1.19, 1.17, 1.20]
  median_s : 1.18

speedup: 3.57x
correctness: identical (loss diff = 0.0)
status: PASS
```

## Failure handling

A strategy is **FAILED** if any of:
- `speedup < 1.05` (within noise — not a real win)
- Output correctness diff exceeds the tolerance for the precision used
- The script crashes (OOM, segfault, import error)

On failure:
1. Append `status: FAILED` to the log with the reason.
2. Pick the next-ranked candidate from `strategies.md` and run it.
3. After 3 consecutive failures across different candidates → emit a `[REPORT-TO-USER]` line: "Tried <X> strategies, none yielded measurable speedup. Recommend manual profiling with `torch.profiler` to find the true bottleneck."

## What to time

Match the slice to the bottleneck class:

| Bottleneck (from sub-skill 2) | What to time                                       |
| ----------------------------- | -------------------------------------------------- |
| IO (data loading)             | One epoch on a representative subset (e.g., 1k samples) |
| GPU compute                   | 10 training steps (warmup 2 + measure 8 with median-of-5 chunks) |
| CPU compute                   | One forward pass with batch size matching prod      |
| H2D / D2H copies              | The copy alone (`x.to('cuda', non_blocking=True); torch.cuda.synchronize()`) |
| All-reduce / comm             | One `dist.all_reduce` of the typical gradient tensor |

The slice must be **small enough to finish in < 60 seconds**. If it takes longer, scale it down. The point is a quick yes/no, not a benchmark suite.

## Self-contained validation script template

Save to `report/efficiency/experiments/<strategy_name>.py`:

```python
#!/usr/bin/env python3
"""Micro-benchmark for strategy <name>.

Usage:  python <strategy_name>.py
Output: prints before/after medians and speedup; writes log to <strategy_name>.log.
"""
import statistics, time, sys, json, datetime
from pathlib import Path

LOG = Path(__file__).with_suffix(".log")

def time_block(fn, n_warmup=2, n_runs=5, sync=None):
    for _ in range(n_warmup):
        fn()
        if sync is not None: sync()
    samples = []
    for _ in range(n_runs):
        t0 = time.perf_counter()
        fn()
        if sync is not None: sync()
        samples.append(time.perf_counter() - t0)
    return statistics.median(samples), samples

def run_before():
    # --- ORIGINAL CODE GOES HERE ---
    pass

def run_after():
    # --- OPTIMIZED CODE GOES HERE ---
    pass

if __name__ == "__main__":
    sync = None  # set to torch.cuda.synchronize for GPU
    b_med, b_samples = time_block(run_before, sync=sync)
    a_med, a_samples = time_block(run_after,  sync=sync)
    speedup = b_med / a_med if a_med > 0 else float("inf")
    status = "PASS" if speedup >= 1.05 else "FAILED"
    log = f"""strategy: <name>
date: {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}
before:
  samples_s: {b_samples}
  median_s : {b_med:.4f}
after:
  samples_s: {a_samples}
  median_s : {a_med:.4f}
speedup: {speedup:.2f}x
status: {status}
"""
    LOG.write_text(log)
    print(log)
    sys.exit(0 if status == "PASS" else 1)
```

## Done condition

`report/efficiency/experiments/` contains a `.log` for each strategy attempted (PASS or FAILED), and at least one PASS exists (otherwise escalate per the failure handling above). Move on to sub-skill 5.
