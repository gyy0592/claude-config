# EXECUTE_LOOP state

Entered from REFLECT (REFLECT_DONE). Inner loop — one iteration = one tool call:

1. `[PLAN]` — one line in action_<sid>.md describing what + why + expected observable, BEFORE the tool call.
2. Tool call (Read / Edit / Write / Bash / Agent).
3. `[OBSERVE]` — one line in action_<sid>.md citing the concrete output that confirms or refutes the [PLAN] expectation. Empty / hand-waved [OBSERVE] = dereliction.
4. Decide: continue (another iteration), anomaly (→ REFLECT on-anomaly), or done (→ REFLECT post-task).

## Anomaly keywords

Used by `execute_loop_audit.sh` to count failure budget:

`refuted | anomaly | fail(ed|ure)? | stuck | unchanged | timeout | exit code [1-9] | traceback | OOM | killed | crash | hang` (case-insensitive).

When you write `[OBSERVE]` and the result disagrees with `[PLAN]`, include at least one of these words so the auditor counts it.

## Failure budget

After 3 consecutive [OBSERVE] entries refuting their [PLAN] in the same EXECUTE_LOOP session, stop and call `transition.sh EXECUTE_EXIT --reason=bug` (see `failure_stop.md`). Override: `$PWD/CLAUDE.md` AUTH keywords.

(Tunables — see `workflow_config.yaml` `execute_loop.failure_budget`.)

## Exit

`transition.sh EXECUTE_EXIT --reason=<bug|done|stuck>`. main is the sole judge of which reason applies — observable evidence must back the choice.
