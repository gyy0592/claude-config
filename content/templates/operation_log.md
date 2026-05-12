<!-- template version = v2.0 (claude-config-v2-hook) -->
# Operation Log — Chronological Stream of Meaningful Operations

**Scope**: Project-level (per `militar_camp/`).
**Granularity**: One entry per "did something meaningful" — NOT per agent micro-action.
**Rule of thumb**: If a future you would want to ask "what changed when?" → log it.

## What counts as a logged operation (examples)

- Modified a yaml field (e.g. `lr: 1e-4` → `5e-5`)
- Enabled / disabled a feature flag (e.g. `torch.compile = True`)
- Added a new file / module (e.g. created `data_loader_v2.py`)
- Ran a non-trivial command (e.g. `sbatch train.sh`, `pip install foo`)
- Made a git commit (record commit hash + 1-line summary)
- Changed environment / dependency (e.g. upgraded torch to 2.5)
- Toggled an experiment switch
- Reverted a previous change

## What does NOT count (don't spam)

- Read a file (use [READ] in soldier_action.md instead)
- Ran a quick check command (use [OBSERVE] entry instead)
- Internal AI thinking (use [REFLECT] entry instead)

## Schema (one entry per row)

| OP # | Time UTC | Actor | What | Why | File / Cmd | Reversible? | Linked Attempt |
|------|----------|-------|------|-----|------------|-------------|----------------|
| OP-1 | 2026-05-12 14:23 | Corporal 1 | Set `batch_size=32` (was 64) | OOM at b=64 on V100 | `configs/train.yaml:12` | Yes (revert commit `abc123`) | ATT-3 |
| OP-2 | 2026-05-12 14:30 | Private 1 | Added `--bf16` flag to launch script | Speed up training | `scripts/launch.sh:8` | Yes | ATT-3 |

## Fill-in rules

- **OP #** — sequential, never reused, never skipped
- **Time UTC** — `YYYY-MM-DD HH:MM` (UTC)
- **Actor** — `Corporal N` or `Private N/M` (corporal_X/numberY)
- **What** — verb + object, concrete (NOT "improved training")
- **Why** — link to ATT-N or bug ID or external request
- **File / Cmd** — exact path:line OR exact command run
- **Reversible?** — `Yes (how)` or `No (because X)`
- **Linked Attempt** — ATT-N from `attempts_ledger.md` if this op is part of a debugging attempt; otherwise `-`

## On-failure protocol

If an operation causes failure (test breaks, perf regresses, etc.):
- Don't delete the log entry — keep it
- Flip its status by adding a new OP-N+1 entry that REVERTS it
- Then add an ATT-N entry to `attempts_ledger.md` marking the original direction as `wrong-direction`
- If significant cost incurred → also add WRONG-WAY-N to `bitter_lessons.md`
