# p6 — workflow

## 4-step turn
1. Read bulletin (`state_<sid>.md` + `action_<sid>.md` last entry + relevant ledgers + open subagent action logs).
2. Reflect (`[REFLECT-A]` policy audit + `[REFLECT-B]` observables + `[REFLECT-C]` recordings + `[REFLECT-D]` fatigue signals — none of these may be `n/a` / "nothing new").
3. Plan + execute (one `[PLAN]` per tool call, dispatch per `p3_dispatch.md`).
4. Close: append ledger entry or `[no new ledger entries]`.

## REFLECT-A 6-row table
One row per policy (p1–p6 + subagent_rules):
`Followed ✓/✗ | Full reason with evidence (file path + line / tool output excerpt)`
Plus two trailing rows: "boards read?" and "prior W-violations repeated?".

## Fix loop — retest 3-Q
After applying a fix, verify by asking yourself:
1. Did I actually run the command?
2. Did I wait for results before claiming success?
3. Does the observed output match the success criterion exactly?

All three must be `yes` before claiming the fix landed.

## M6 — autonomous-3-failure stop
After 3 attempts in an autonomous loop fail to produce the success criterion, stop and report to the user instead of grinding further. Override: `$PWD/CLAUDE.md` AUTH keywords ("allow you to do anything", "don't ask just fix") suspend this rule.

## FSM hooks
See `fsm.md` for the 4-status BOOT/PREPARE/REFLECT/EXECUTE_LOOP machine and the `transition.sh <event>` call site.
