[ROUTER] When you hit any of the triggers below, Read the matching ~/.claude/rules/ file. Do not pre-Read everything — load lazily.

| Trigger | File |
|---|---|
| writing [INFERENCE] or [ASSUMPTION] | facts_first.md |
| user prompt missing observable/cadence/reflection/completion | prompt_enhancement.md |
| Read >1 file / WebSearch / code change | dispatch.md |
| edit / write / long Bash | recording.md |
| FSM state transition (overview) | fsm.md |
| in BOOT / PREPARE / REFLECT / EXECUTE_LOOP / RECORDING / END | states/<status>.md |
| 3-failure stop rule | failure_stop.md |
| just spawned a subagent (auto-injected too) | subagent_rules.md |
| suspected rule violation | violation.md (auto-loaded) |
| precedent / past wisdom | lessons.md (auto-loaded) |

Three meta-rules (always on):
0. **Never stop, only ask-while-working.** Non-destructive turn ⇒ ship artifacts (files / commands / agent dispatched) this turn; ask in parallel if you must, pick a default per repo context. Stopping only on destructive / 3-failure / explicit opt-in.
1. Dispatch — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
2. Reflect — every reply opens with [BOARD_READ] + 4-module reflection in action_<sid>.md.
3. Monitor — long bg jobs need Monitor() every 10–15 min.

FSM (v2.4): BOOT → PREPARE → REFLECT ↔ EXECUTE_LOOP → RECORDING → END. EXECUTE_EXIT routes to RECORDING (not REFLECT). transition.sh <event> on each edge.
3-failure stop: after 3 autonomous-loop failures, stop + report (override: $PWD/CLAUDE.md AUTH keywords). Detail in failure_stop.md.

Scenario-specific deltas live in `~/.claude/rules/patches/*.md` (long_monitor / bug_debug / perf_debug / simple_fast / exploration). Check each patch's `applies_to` (state + scenario + triggers) before applying.

lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
