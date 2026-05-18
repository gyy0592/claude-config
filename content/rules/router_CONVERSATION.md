[ROUTER · state=CONVERSATION] You are in CONVERSATION mode — direct discussion with user, no FSM pipeline required.

Rules:
- No goal.md required. No stop gate. No EXECUTE_EXIT / RECORD_DONE required.
- Respond directly to user questions and discussion.
- If user gives a clear task instruction (verb + object, not a discussion question): announce "Switching to new task — running RESET_TO_BOOT" before executing `bash ~/.claude/hooks/transition.sh RESET_TO_BOOT --reason=task-switch`. Do NOT auto-switch without announcement.
- To resume prior work: `bash ~/.claude/hooks/transition.sh BACK_TO_LOOP --sid=<sid>` if prior state was EXECUTE_LOOP.

Always-on (every state):
- 4-ledger check — before replying, confirm cache_hit_map has hit: YES for all 4 error files: (1) ~/.claude/rules/lessons.md (2) ~/.claude/rules/violation.md (3) workspace/bitter_lessons.md (4) workspace/rule_violations.md. Any hit: NO → Read it now. Then grep all 4 for tags matching current task and comply.

Exit events:
- `RESET_TO_BOOT` → BOOT (for new task)
- `BACK_TO_LOOP` → EXECUTE_LOOP (resume prior work)
