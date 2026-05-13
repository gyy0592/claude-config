# Claude Stop-Gate Status

<!-- Stop hook reads this file. ALL items in [STOP-GATE] must equal 1 for AI to stop. -->
<!-- AI updates these values as work progresses. At start of each new turn, AI resets relevant items to 0. -->
<!-- File is initialized by init_corporal.sh; AI maintains it from there. -->

[STOP-GATE]
current_goal_complete: 0     # 1 = goal complete with retest ✅ (hands-on) or cited evidence (Q&A)
action_log_written: 0        # 1 = corporal_action.md entry written this turn
six_decree_audit_done: 0     # 1 = REFLECT-A 6-row table written this turn
violations_all_recorded: 1   # 0 = any "I broke X" confession this turn unrecorded; 1 otherwise (default 1)
no_abandoned_work: 0         # 1 = no mid-flight work being skipped

[LONG_RUNNING_JOBS]
# Track long-running tasks here. Stop hook IGNORES this section.
# Schema example:
# job-1: slurm_id=12345  status=running  started=2026-05-12T14:00Z  last_monitor=2026-05-12T14:15Z  bash_id=bg-abc
# AI calls Monitor tool every 10-15 min to check; update last_monitor + status fields.

[NOTES]
# Free-form notes. Stop hook ignores anything outside [STOP-GATE].
