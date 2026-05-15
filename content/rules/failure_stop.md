# failure_stop — autonomous 3-failure stop (M6)

After 3 attempts in an autonomous loop fail to produce the success criterion, stop and report to the user instead of grinding further.

This is one of the three sanctioned conditions for mid-task user interruption (alongside destructive ops and explicit user opt-in — see `autonomy.md`).

Failure counting: `[OBSERVE]` entries that refute their `[PLAN]` within the same EXECUTE_LOOP session count as failures. `execute_loop_audit.sh` enforces this via the anomaly-keyword scan in `states/execute.md`.

Action on third failure: call `transition.sh EXECUTE_EXIT --reason=bug` and surface to user.

## Fix-loop retest 3-Q (kept from v1 workflow)

After applying a fix, before claiming success:
1. Did I actually run the command?
2. Did I wait for results before claiming success?
3. Does the observed output match the success criterion exactly?

All three must be `yes` before claiming the fix landed.
