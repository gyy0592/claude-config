[ROUTER · state=EXECUTE_LOOP] You are in EXECUTE_LOOP. Do the work. [PLAN] → tool → [OBSERVE].

→ Full pipeline (iteration pattern / failure budget / Monitor cadence): `cat ~/.claude/rules/states/execute.md`
→ 3-failure stop: `cat ~/.claude/rules/failure_stop.md`
→ Audit helper: `bash ~/.claude/hooks/execute_loop_audit.sh`
→ Advance when deliverable done: `bash ~/.claude/hooks/transition.sh EXECUTE_EXIT --reason=<completion|bug|anomaly|stuck>` → RECORDING (v2.4: ledgers, then END)
→ Mid-loop record (without exiting work): `bash ~/.claude/hooks/transition.sh NEED_RECORD --reason="<short>"` → RECORDING, then `BACK_TO_LOOP` to resume here
→ User changed task mid-session (new goal.md / unrelated request): `bash ~/.claude/hooks/transition.sh RESET_TO_BOOT --reason=task-switch` → BOOT (re-read updated goal.md)

Quick rules: all tools allowed. Required = [PLAN] before / [OBSERVE] after every mutator or long Bash. Agent must be run_in_background=true. Long jobs need Monitor() cadence.

Scenario patches (read on demand, applies_to filter): patches/long_monitor.md / bug_debug.md / perf_debug.md / simple_fast.md / exploration.md.

Recording rule (MUST, always-on in EXECUTE_LOOP):
  **In EXECUTE_LOOP, Edit/Write to any ledger path is denied by a PreToolUse hook** (paths listed under `recording.guarded_paths` in workflow_config.yaml).
  To record ⇒ MUST `bash ~/.claude/hooks/transition.sh NEED_RECORD --reason="<one-line>"` to RECORDING, write there, then `BACK_TO_LOOP` back here.
  No ledger entry this turn ⇒ write `[no new ledger entries this turn]` in action.md explicitly.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ background subagent dispatch.
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - 4-ledger check — before replying, confirm cache_hit_map has hit: YES for all 4 error files: (1) ~/.claude/rules/lessons.md (2) ~/.claude/rules/violation.md (3) workspace/bitter_lessons.md (4) workspace/rule_violations.md. Any hit: NO → Read it now. Then grep all 4 for tags matching current task and comply.
  - autonomy.md — do NOT ask the user. Allowed only on (a) destructive ops, (b) 3-failure-stop, (c) prior explicit user opt-in. Otherwise REFLECT subagent rebuttal + decide yourself.
