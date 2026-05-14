[ROUTER · state=EXECUTE_LOOP] You are in EXECUTE_LOOP. Do the work. [PLAN] → act → [OBSERVE].

Must-read on entry:
  ~/.claude/rules/states/execute.md
  ~/.claude/rules/failure_stop.md
  ~/.claude/rules/workflow_config.yaml (execute_loop.failure_budget / monitor_short / monitor_long)

Helpers:
  bash ~/.claude/hooks/execute_loop_audit.sh   # PLAN/OBSERVE pairing + anomaly count

Allowed: every tool. Required pattern: write [PLAN] in action.md before Edit/Write/long Bash; write [OBSERVE] after.
Forbidden: silent edits without [PLAN]; non-bg dispatch (Agent must be run_in_background=true); long jobs without Monitor cadence (10–15 min default; tune via patches/long_monitor.md).

Failure budget: 3 anomalies → call `transition.sh EXECUTE_EXIT --reason=bug` → REFLECT (unless $PWD/CLAUDE.md AUTH override).

Before advancing — finish ALL of these:
  - Deliverable produced (file modified, test passed, output captured)
  - PLAN/OBSERVE counts match (run `execute_loop_audit.sh` to verify)
  - No outstanding [TODO] markers in action.md
  - For long jobs: Monitor() cadence respected; no silent runaway

Forget any of the above? → `cat ~/.claude/rules/states/execute.md` + `cat ~/.claude/rules/failure_stop.md`.

Advance only when checklist done: `bash ~/.claude/hooks/transition.sh EXECUTE_EXIT --reason=<completion|bug|anomaly>` → REFLECT.

Always-on:
  - facts_first.md (INFERENCE_GATE).
  - dispatch.md.
  - recording.md.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.

Scenario patches (read on demand from ~/.claude/rules/patches/, filter by applies_to):
  patches/long_monitor.md  patches/bug_debug.md  patches/perf_debug.md
  patches/simple_fast.md   patches/exploration.md
