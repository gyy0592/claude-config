---
id: P-001
created: 2026-05-14T00:00:00Z
source: human
scope: global
applies_to:
  state: [EXECUTE_LOOP]
  scenario: long_monitor
  triggers:
    - tool: Bash
      cmd_regex: "sbatch|squeue|qsub|qstat|while true|tail -f|sleep [0-9]{2,}"
    - tool: Agent
      bg_polling: true
priority: 100
status: active
---

## what

Replace fsm.md's default 10–15 min Monitor cadence with a 3-tier adaptive cadence tuned for long-running background jobs (training, queued sbatch, polling agents).

## why

- L-014 / L-015 / L-016: stochastic 8-run batches range 3–60 min; a fixed 10 min cadence either spams the log or misses freeze signals.
- VRAM trend (L-015) and NPZ growth (L-014) are stronger ground-truth signals than time.

## how

Cadence (override fsm.md default Monitor schedule):
- `T_queue = max(60s, queue_estimate / 5)` — while job is pending.
- `T_run = max(60s, run_estimate / 20)` — once worker active.
- After 2 consecutive clean polls (no anomaly, VRAM growing), back off to `run_estimate / 5`.
- Hard ceiling: poll at least once every 75 min regardless of estimate (L-016 freeze threshold for stochastic jobs; 40 min for greedy).

Observables to record per poll (NOT just time):
- nvidia-smi util + VRAM MiB delta vs previous poll
- output artifact count growth (NPZ / events.jsonl / checkpoint)
- log file tail-N delta

Freeze decision:
- silence > 75 min AND VRAM stable AND artifact count unchanged → escalate
- silence > 40 min AND VRAM stable for greedy job → escalate
- otherwise keep polling

## examples

JOB 1092 worker_03 silent 59.4 min — VRAM grew 56249→58703 MiB → still computing, do not escalate.
