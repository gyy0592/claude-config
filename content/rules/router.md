[ROUTER] When you hit any of the triggers below, Read the matching ~/.claude/rules/ file. Do not pre-Read everything — load lazily.

| Trigger | File |
|---|---|
| writing [INFERENCE] or [ASSUMPTION] | facts_first.md |
| Read >1 file / WebSearch / code change | dispatch.md |
| edit / write / long Bash | recording.md |
| FSM state transition (overview) | fsm.md |
| in BOOT / PREPARE / REFLECT / EXECUTE_LOOP / END | states/<status>.md |
| 3-failure stop rule | failure_stop.md |
| just spawned a subagent (auto-injected too) | subagent_rules.md |
| suspected rule violation | violation.md (auto-loaded) |
| precedent / past wisdom | lessons.md (auto-loaded) |

Three meta-rules (always on):
1. Dispatch — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
2. Reflect — every reply opens with [BOARD_READ] + 4-module reflection in action_<sid>.md.
3. Monitor — long bg jobs need Monitor() every 10–15 min.

FSM: BOOT → PREPARE → REFLECT ↔ EXECUTE_LOOP. transition.sh <event> on each edge.
3-failure stop: after 3 autonomous-loop failures, stop + report (override: $PWD/CLAUDE.md AUTH keywords). Detail in failure_stop.md.
