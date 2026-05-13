# Claude Stop-Gate Status (per-session)

<!-- File location: .claude_status/{session_id}_status.md -->
<!-- Stop hook reads this file. ALL items in [STOP-GATE] must equal 1 or NA. -->
<!-- AI flips each item to 1 (followed) or NA (inapplicable) with a reason after #. -->
<!-- Reset hook auto-zeros every item at start of each turn. -->
<!-- Value=0 blocks stop; NA allowed only when truly inapplicable. -->

[STOP-GATE]
# Schema: <rule>: <1|0|NA>  # <evidence/reason — REQUIRED, not blank>

d1_identity_correct: 0           # self="Corporal", other="Commander", no "user/Claude/assistant"
d2_sentences_tagged: 0           # every sentence has [FACT]/[INFERENCE]/[ASSUMPTION]
d2_inference_proper: 0           # [INFERENCE] used? has effort log + 2nd reflection / NA
d3_dispatched_if_needed: 0       # >1 file / WebSearch / code → Agent + run_in_bg=true; or main thread OK
d3_monitor_verified: 0           # bg task: Monitor done + status verified running / NA
d3_failure_modes_listed: 0       # for each running task: 3+ failure modes + observable vars listed / NA
d4_action_log_written: 0         # corporal_action.md written before reply, record-before-op
d4_violation_synced: 0           # confession this turn? W-XXX in repo violation.md + mirrored in action.md / NA
d5_read_tool_only: 0             # all reads via Read tool, no memory claims
d6_reflect_4_modules: 0          # REFLECT-A/B/C/D all substantive (D no boilerplate)
d6_retest_3q: 0                  # ran cmd + waited results + matched success criterion / NA
m5_prompt_reinforced: 0          # instruction had 4-item kit? weak → [PROMPT REINFORCED] written / NA
m6_executed_not_reasking: 0      # authorized → execute, not re-ask. Destructive (8-item) → asked / NA
cg_goal_read_from_file: 0        # read $PWD/.claude_status/goal.md; followed it; did NOT modify it
br_boards_read: 0                # §6 reading list (situation/status/action-last/ledgers/soldier_action) done

[LONG_RUNNING_JOBS]
# Auto-rebuilt by reset_session_status.sh every turn — alive tasks discovered via lsof.

[NOTES]
# Free-form. Stop hook ignores anything outside [STOP-GATE].
