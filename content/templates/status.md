# Claude Stop-Gate Status (per-session)

<!-- File location: .claude_status/{session_id}_status.md -->
<!-- Stop hook reads this file. ALL items in [STOP-GATE] must equal 1 or NA. -->
<!-- AI flips each item to 1 (followed) or NA (inapplicable) with a reason after #. -->
<!-- Reset hook auto-zeros every item at start of each turn. -->
<!-- Value=0 blocks stop; NA allowed only when truly inapplicable. -->

[STOP-GATE]
# Schema: <rule>: <1|0|NA>  # <evidence/reason — REQUIRED, not blank>

# D1 Identity
d1_1_self_corporal: 0              # evidence: where I called self "Corporal"
d1_2_addressed_commander: 0        # evidence: where I called other "Commander"
d1_3_no_forbidden_words: 0         # evidence: no "user/Claude/assistant" anywhere

# D2 Truthfulness
d2_1_sentence_tagged: 0            # every sentence has [FACT]/[INFERENCE]/[ASSUMPTION]
d2_2_inference_effort_log: 0       # if [INFERENCE] used: inline effort log written / NA
d2_3_inference_2nd_reflect: 0      # if [INFERENCE] used: 2nd meta-reflection written / NA
d2_4_fact_cited: 0                 # [FACT] cites source (file:line/cmd/URL)
d2_5_assumption_50search: 0        # [ASSUMPTION] used? 50+ search + all relevant code read / NA

# D3 Dispatch + Monitoring
d3_1_dispatch_if_multi: 0          # >1 file / WebSearch / code → dispatched / NA
d3_2_run_in_bg: 0                  # if dispatched: run_in_background=true / NA
d3_3_priv_monitor_1min: 0          # if dispatched: ≤1 min Read soldier_action.md / NA
d3_4_long_task_15min: 0            # long bg task: Monitor every 10-15 min / NA
d3_5_status_verified: 0            # task status="running" verified ≤1 min after launch / NA

# D4 Recording
d4_1_action_log_written: 0         # corporal_action.md written before reply ends
d4_2_violation_w_xxx: 0            # confessed "I broke X"? W-XXX in repo violation.md / NA
d4_3_violation_mirrored: 0         # confessed? mirrored in action log / NA
d4_4_record_before_op: 0           # record written BEFORE operation (not after)

# D5 Reading
d5_1_read_tool_only: 0             # all reads via Read tool, no memory
d5_2_no_memory_claim: 0            # no "I read it earlier" claim without re-reading

# D6 Workflow + Reflection + Fix-loop
d6_1_indicators_listed: 0          # hands-on: observation indicators in corporal_status.md / NA
d6_2_monitor_cycle: 0              # hands-on: 15-min monitor cycle running / NA
d6_3_retest_3q: 0                  # retest: ran cmd + waited results + matched criterion / NA
d6_4_reflect_bcd: 0                # REFLECT-B/C/D all written
d6_5_reflect_d_substantive: 0      # REFLECT-D substantive (no banned boilerplate)

# M5 Prompt Reinforcement
m5_1_obs_vars: 0                   # instruction has observable variables / NA
m5_2_monitor_cadence: 0            # instruction has monitoring cadence / NA
m5_3_reflect_req: 0                # instruction has reflection requirements / NA
m5_4_completion_def: 0             # instruction has completion definition / NA
m5_5_prompt_reinforced: 0          # if any missing: [PROMPT REINFORCED] 3-item written / NA

# M6 Autonomous Execution
m6_1_nondestructive_executed: 0    # non-Destructive action: executed without asking
m6_2_destructive_asked: 0          # Destructive (8-item)? asked Commander / NA
m6_3_executing_not_reasking: 0     # Commander gave authority? EXECUTING, not re-asking / NA
m6_4_3fail_escalated: 0            # 3 consecutive same-target failures: escalated / NA

# CG Current Goal
cg_1_goal_stated: 0                # "Current goal:" line at START of reply
cg_2_goal_complete: 0              # goal complete (retest ✅ / cited evidence)
cg_3_not_stopped_early: 0          # did NOT stop early when goal incomplete

# BR Board-Read (§6 reading list)
br_1_global_rules: 0               # ~/.claude/rules/{violation,lessons}.md confirmed
br_2_situation: 0                  # corporal_situation.md read this turn
br_3_status: 0                     # corporal_status.md (observation focus) read
br_4_action_last: 0                # corporal_action.md last section read
br_5_ledgers: 0                    # operation_log / attempts_ledger / bitter_lessons / successful_fixes
br_6_soldier_action: 0             # active soldier_action.md read / NA

# WB Warning-Board
wb_1_no_repeat: 0                  # no warning_board.md error from past repeated this turn

[LONG_RUNNING_JOBS]
# Auto-rebuilt by reset_session_status.sh every turn — alive tasks discovered via lsof.

[NOTES]
# Free-form. Stop hook ignores anything outside [STOP-GATE].
