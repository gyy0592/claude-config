# EXECUTE_LOOP — the working state

You are in EXECUTE_LOOP. Do the actual task work. Each iteration follows the same pattern. The state machine guarantees the surrounding discipline (rebuttal, ledgers, post-task verify) so you focus on the work.

## Inner iteration pattern (every tool call)

### Step 1 — `[PLAN]` BEFORE the tool call

Append to action.md:

```
[PLAN @ ts] <verb> <object> — expecting <observable>
```

Examples:
- `[PLAN] Edit src/foo.py:42 — expecting KeyError to disappear when running test_foo.py`
- `[PLAN] Bash python -m pytest tests/ — expecting all 14 pass`
- `[PLAN] sbatch train.sh — expecting job_id returned + state=PD`

### Step 2 — Make the tool call

Use Edit / Write / Bash / Read / Agent / WebSearch as needed.

For Agent: `run_in_background=true` is **mandatory** (`dispatch.md`).
For bg Bash: `run_in_background=true`; for any wall-time ≥ 5 min, set Monitor cadence per Step 5.

### Step 3 — `[OBSERVE]` AFTER the tool call

Append to action.md citing the concrete output:

```
[OBSERVE @ ts] <what happened> — observed <concrete data>
```

Examples:
- `[OBSERVE] Edit applied — line 42 now reads foo.get(key, default); test_foo.py exits 0`
- `[OBSERVE] pytest output — 14 passed, 0 failed, 2.3s`
- `[OBSERVE] sbatch returned 12345 — squeue shows state=PD position=23`

**Empty / hand-waved `[OBSERVE]`** ("looks good", "should work") = behavioral error → append to `workspace/rule_violations.md` with current `task:`.

### Step 4 — Decide

Compare `[OBSERVE]` to `[PLAN]`:
- Matches → next iteration
- Refutes → **anomaly** (Step 6 budget)
- Deliverable complete → exit via `EXECUTE_EXIT --reason=completion`

### Step 5 — Long-job Monitor cadence

For bg jobs (`run_in_background=true`):

| wall-time | cadence |
|---|---|
| < 5 min | check once on completion notification |
| 5–60 min | `Monitor(bash_id=...)` every 10–15 min |
| > 60 min | `Monitor(persistent=true)` OR cross-session via `CronCreate` |

Adaptive cadence for monitoring tasks: see `patches/long_monitor.md` (T_queue/5 → T_run/20 → T_run/5 after 2 clean polls).

Skipping Monitor on a long bg job = dereliction.

### Step 6 — Failure budget (autonomous-3-failure stop)

If 3 consecutive `[OBSERVE]`s refute their `[PLAN]`:
- Stop the loop
- Run: `bash ~/.claude/hooks/transition.sh EXECUTE_EXIT --reason=bug`
- The transition will cat `states/reflect.md` for on-anomaly rebuttal

**Anomaly keywords** the audit counts (write at least one when refuting):

```
fail | failure | failed | refuted | anomaly | exit code [1-9] |
traceback | error | crash | OOM | killed | timeout | stuck |
unchanged | inefficient | bottleneck | underutilized | hang
```

**Override** — if `$PWD/CLAUDE.md` contains `allow you to do anything` or similar AUTH keyword, autonomous-3-failure stop suspended (see `failure_stop.md`).

### Step 7 — Audit helper (anytime)

```
bash ~/.claude/hooks/execute_loop_audit.sh
```

Reports `[PLAN]` count vs `[OBSERVE]` count + anomaly count. Run before EXECUTE_EXIT to catch missing `[OBSERVE]`s.

## Allowed
- All tools
- Required: `[PLAN]` before mutator / long Bash / Agent; `[OBSERVE]` after
- Subagents (must be `run_in_background=true`)

## Forbidden
- Silent edits without `[PLAN]`
- Foreground (non-bg) Agent calls
- Long jobs without Monitor cadence
- > 3 consecutive anomalies without EXECUTE_EXIT
- Claiming "done" without running the verification the `[PLAN]` expected

## Completion criteria — ALL must be true before advancing

- [ ] Deliverable produced (file modified / test passed / output captured / artifact landed)
- [ ] `[PLAN]` / `[OBSERVE]` counts match (audit helper green)
- [ ] No outstanding `[TODO]` markers in action.md
- [ ] For long jobs: completion observed (not just dispatched)
- [ ] anomaly count < 3 (or AUTH override engaged)

## Advance

```
bash ~/.claude/hooks/transition.sh EXECUTE_EXIT --reason=<completion|bug|anomaly|stuck>
```

Reason routing:
- `completion` → REFLECT (post-task verification)
- `bug` / `anomaly` → REFLECT (on-anomaly rebuttal)
- `stuck` → REFLECT (post-task) + surface to user

→ Next state: REFLECT. The transition script will cat `states/reflect.md`.
