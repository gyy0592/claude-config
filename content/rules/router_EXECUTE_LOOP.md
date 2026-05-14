[ROUTER · state=EXECUTE_LOOP] You are in EXECUTE_LOOP. Do the work. [PLAN] → tool → [OBSERVE].

→ Full pipeline (iteration pattern / failure budget / Monitor cadence): `cat ~/.claude/rules/states/execute.md`
→ 3-failure stop: `cat ~/.claude/rules/failure_stop.md`
→ Audit helper: `bash ~/.claude/hooks/execute_loop_audit.sh`
→ Advance when deliverable done: `bash ~/.claude/hooks/transition.sh EXECUTE_EXIT --reason=<completion|bug|anomaly|stuck>` → REFLECT
→ User changed task mid-session (new goal.md / unrelated request): `bash ~/.claude/hooks/transition.sh RESET_TO_BOOT --reason=task-switch` → BOOT (re-read updated goal.md)

Quick rules: all tools allowed. Required = [PLAN] before / [OBSERVE] after every mutator or long Bash. Agent must be run_in_background=true. Long jobs need Monitor() cadence.

Scenario patches (read on demand, applies_to filter): patches/long_monitor.md / bug_debug.md / perf_debug.md / simple_fast.md / exploration.md.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
