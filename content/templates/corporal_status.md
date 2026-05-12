<!-- template version = v1.2 (claude-config) -->
# Corporal X CLAUDE Status File

<!-- This file is created by init_corporal.sh. Within 30 seconds, must write the first [BOARD_READ] entry in corporal_action.md, otherwise Dereliction of Duty. -->

**Rank**: Corporal
**Number**: Corporal X
**Superior**: Commander
**Assignment Time**: YYYY-MM-DD HH:MM UTC

## Commander's Instructions Verbatim (this session)

<!-- Verbatim copy, no rewriting / summarizing -->
1. ...
2. ...
3. ...

## Status

- Current task: <brief description>
- Dispatched Privates: <list number1, number2, ...>
- Queue: <pending>

## Observation Checklist (fill each section independently; sections must not be deleted; empty sections write "not applicable to this task"; each section ≤ 3 items; 6-field schema — missing any field = that entry is void)

### Section 1 — Task Workflow Observation Items (mandatory — Private return / dispatch progress / file Read completion, etc.)

| # | Decidable Proposition | Measurement Command (non-blocking < 1s) | Expected Output | Failure Signal | Severity |
|---|-----------------------|-----------------------------------------|-----------------|----------------|----------|
| obs-1 | Example: Private numberY has returned full report | `wc -l corporal_X/numberY/soldier_action.md` | ≥ 100 lines + [return] block present | < 100 lines / 30s no write / [SILENCE_START] timeout | blocker |

### Section 2 — Resource / Performance Monitoring (mandatory for hands-on tasks; investigation / pure Q&A may write "not applicable to this task")

| # | Decidable Proposition | Measurement Command | Expected Output | Failure Signal | Severity |
|---|-----------------------|---------------------|-----------------|----------------|----------|
| obs-N | Example: GPU memory does not overflow | `nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits` | < total memory × 0.95 | OOM / NaN / inf | blocker |

### Section 3 — Code / Model Robustness (mandatory for tasks involving code / training / inference / documentation modification)

| # | Decidable Proposition | Measurement Command | Expected Output | Failure Signal | Severity |
|---|-----------------------|---------------------|-----------------|----------------|----------|
| obs-N | Example: set_claude.sh bash syntax OK | `bash -n set_claude.sh` | exit 0 | exit != 0 / stderr | blocker |

### Section 4 — Inference Exhaustive Self-Check (triggered by Decree 2; every [INFERENCE] must add one row)

| # | [INFERENCE] original text (≤ 50 chars) | Code already read (file:line list) | Commands already run | Keywords searched + count | Thought experiment done | Upgraded to [FACT]? |
|---|----------------------------------------|------------------------------------|----------------------|---------------------------|-------------------------|---------------------|
| obs-N | Example: J5 agg=57% vs base=32% inconsistency is due to different paths | inject_dual_agg_mv.py:1-500, stage5_output/compute_fair/*.py | `diff <(grep max_new_tokens A) <(grep max_new_tokens B)` | "GSM8K agg base single greedy difference" × 50 | No | No |

### Section 5 — Private Progress Monitoring (mandatory after dispatching Privates)

| Private # | Task Summary (≤ 30 chars) | Last Read soldier_action.md Time | Next Monitor Time (5-minute cycle) | Status |
|-----------|---------------------------|----------------------------------|------------------------------------|--------|
| numberY | <summary> | YYYY-MM-DD HH:MM UTC | last + 5 min | running / COMPLETED / pending review |

Fill-in rules:
- "Decidable proposition" must be answerable with a clear "pass / fail".
- "Measurement command" must be copy-pasteable and directly runnable, **non-blocking < 1 second return** (forbidden: `tail -f` / `watch` / `while true` / long `sleep` — see Decree 3 monitor iron rules).
- "Failure signal" must contain ≥ 1 item: `NaN` / `OOM` / `timeout` / `performance degradation` / `abnormal stderr` / `skipped tests` / `silently fell back to backup plan`, etc.
- Section 4: each [INFERENCE] must be on its own row; after upgrading to [FACT], keep the row (mark "Yes") as audit trail.
- Detailed rules and failure 3-step fix-loop → see content/memory/workflows.md.

Exemption: pure Q&A / no file reading or writing may write "task mode = stateless, reason: <specific explanation>" to skip; wrong task mode = False Military Report.
