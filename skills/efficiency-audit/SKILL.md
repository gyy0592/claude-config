---
name: efficiency-audit
description: Audits whether the current code is already running at maximum speed by checking GPU/CPU/IO bottleneck saturation. Red-alarms if NONE of GPU/CPU/IO is bottlenecked — that proves speedup is mathematically possible and the code is wasting compute. Loads 5 sub-skills progressively. Trigger this skill aggressively whenever the user asks about speed, performance, throughput, latency, "why is this slow", "is my code optimal", "can I make this faster", "find the bottleneck", profiling, optimization, GPU utilization, dataloader speed, training speed, inference speed, 性能, 加速, 瓶颈, 慢, 优化, 训练慢, 推理慢, even when the user doesn't explicitly use the word "audit". Also trigger when reviewing training scripts, inference scripts, or any data-processing pipeline for efficiency. Skip only if the user clearly asks about correctness, not speed.
---

# efficiency-audit — Audit whether code is already running at maximum speed

## The Red Alarm (the one insight that matters)

A program can run no faster than its slowest physical resource. Therefore: **if NONE of GPU compute, CPU compute, or IO bandwidth is bottlenecked (>= ~70% saturated), the code is provably leaving speed on the table.** No further measurement is needed to know speedup is possible — only to know how much.

This skill turns the vague question "is my code fast?" into a binary verdict (red alarm vs green) plus a concrete improvement plan backed by micro-benchmarks.

Saying "the code looks fine" without measuring saturation is malpractice. So is profiling for hours before checking the ceiling. This skill prevents both.

## Prerequisites

- A target code path (training loop, inference script, data-processing pipeline). Either a file path or a clear description of which entry-point script the user wants audited.
- A working shell on the machine the code runs on (to call `nvidia-smi`, `lscpu`, `dd`).
- Python ≥ 3.8 (for the experiment-validation sub-skill).

## The 5-step workflow — load each sub-skill in order

The sub-skills live as **sibling files** in this directory. Read each one when you reach its step. Do **not** read all five upfront — that defeats the progressive-disclosure design and wastes context.

| Step | Sub-skill file                                       | Purpose                                                              | Output artifact                              |
| ---- | ---------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------- |
| 1    | `01-theoretical-limits.md`                           | Measure GPU/CPU/IO ceilings of this machine                          | `report/efficiency/theoretical_limits.yaml`  |
| 2    | `02-pipeline-analysis.md`                            | Estimate the code's actual demand by READING the source (no profiling — too slow) | `report/efficiency/analysis.html`            |
| 3    | `03-bottleneck-reflection.md`                        | Two rounds of brainstorming improvements (basic + advanced)          | `report/efficiency/strategies.md`            |
| 4    | `04-experiment-validation.md`                        | Micro-benchmark the top 3 strategies (before/after timings)          | `report/efficiency/experiments/*.log`        |
| 5    | `05-final-report.md`                                 | Produce the final HTML with diff + numbers + how-to-reproduce        | `report/efficiency/final_report.html`        |

Each sub-skill is **standalone-readable** — it lists its own prerequisites and inputs at the top, so an agent dropped into step 3 directly can still execute. But the natural flow is 1 → 2 → 3 → 4 → 5, and outputs of each feed the next.

## Concrete invocation pattern

```text
Agent reads SKILL.md  (this file)
   ↓
Agent reads 01-theoretical-limits.md  →  runs commands  →  writes theoretical_limits.yaml
   ↓
Agent reads 02-pipeline-analysis.md   →  greps user code →  writes analysis.html
   ↓
Agent compares ceiling vs estimated actual demand
   ├── if some resource is >= 70% saturated → "GREEN: bottlenecked on <X>; remaining speedup requires changing algorithm/hardware"
   └── if NO resource is >= 70% saturated   → "RED ALARM: speedup mathematically possible. Proceed to step 3."
   ↓
Agent reads 03-bottleneck-reflection.md  →  writes strategies.md (≥ 5 basic + ≥ 3 advanced candidates, ranked)
   ↓
Agent reads 04-experiment-validation.md  →  runs micro-benchmarks  →  writes experiments/*.log
   ↓
Agent reads 05-final-report.md           →  writes final_report.html with diff + before/after bar chart
```

## Output directory convention

All artifacts go under `report/efficiency/` (relative to the repo root being audited). The directory layout is:

```
report/efficiency/
├── theoretical_limits.yaml      # step 1 output (machine ceilings)
├── analysis.html                # step 2 output (pipeline diagram + estimated demand)
├── strategies.md                # step 3 output (ranked improvement candidates)
├── experiments/                 # step 4 output
│   ├── <strategy_a>.log
│   └── <strategy_b>.log
└── final_report.html            # step 5 output (the deliverable for the user)
```

Create this directory on demand; do not write artifacts elsewhere.

## Failure / escalation rules

- If `nvidia-smi` is missing AND the user's code references `.cuda()` / `.to('cuda')` — write a `[WARNING] No GPU detected but code expects one. Auditing CPU-only path; GPU ceiling marked N/A.` to `theoretical_limits.yaml` and continue with the CPU/IO analysis. Do NOT abort.
- If the GPU model is not in the lookup table in `01-theoretical-limits.md` — write `UNKNOWN — fill in manually` for the FP16/FP32 cells, but continue. The pipeline analysis (step 2) and reflection (step 3) still work without exact TFLOPs.
- If a strategy fails in step 4 (no measurable speedup OR breaks correctness) — mark it FAILED in the log, return to step 3, and pick the next-ranked strategy. Max 3 retries per strategy.

## Why "no profiling" in step 2?

Profilers (PyTorch profiler, nsight, py-spy) require a full training run instrumented and tend to take minutes to hours and add overhead that distorts the measurement. For an **audit** — a quick check on whether the code is even in the right ballpark — static analysis of the source plus the theoretical ceilings is enough to detect the red-alarm case (no resource saturated). Reserve profilers for after the red alarm is cleared and you're hunting for residual inefficiency.

## What this skill is NOT

- It is not a correctness reviewer. If the code has bugs, this skill won't find them.
- It is not a profiler. It estimates demand from source code, not from a running process.
- It is not exhaustive. It catches the common 10x-wasting mistakes (data loading, AMP off, unbatched IO, redundant CPU↔GPU copies). For sub-percent optimizations, use a real profiler.

## When the agent is finished

The final deliverable to the user is `report/efficiency/final_report.html` plus a one-paragraph summary in the chat:
- Verdict (RED / GREEN)
- Top bottleneck
- Recommended top-3 changes
- Measured speedups from step 4
