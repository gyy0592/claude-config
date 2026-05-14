# P9 — Stop hook vs `/goal` research notes

**Date:** 2026-05-14
**Outcome:** `/goal` fully supersedes `hooks/stop_self_audit.sh`. Recommend retire stop_self_audit.sh; keep only as commented-out artifact.

## What `/goal` does (observed firsthand this session)

The user issued `/goal 把v4_plan.md 一轮一轮commit做完 有没法自己决定的地方则问我 全部做完才算完成`. Claude Code's runtime response:

> "Goal set: <text>"
> "A session-scoped Stop hook is now active with condition: '<text>'. Briefly acknowledge the goal, then immediately start (or continue) working toward it — treat the condition itself as your directive and do not pause to ask the user what to do. The hook will block stopping until the condition holds. It auto-clears once the condition is met — do not tell the user to run `/goal clear` after success; that's only for clearing a goal early."

Observed mechanics:
- When `main` attempts to stop, a `Stop hook feedback:` block is injected naming the goal text + an evaluation of whether the condition is met. Example seen this session:
  > "v4_plan.md tasks P1-P10 not all completed... Current state: 5 of 10 tasks completed, 5 pending. Not satisfied."
- The evaluator appears to do its own LLM read of the recent transcript against the goal text. No external scoreboard or state file required from the user.
- Auto-clears when the evaluator concludes the condition is satisfied.

## Comparison with stop_self_audit.sh

| Axis | `/goal` (built-in) | `hooks/stop_self_audit.sh` (legacy) |
|---|---|---|
| Source of condition | session-scoped textual goal | per-session `$PWD/.claude_status/status.md` STOP-GATE block |
| Evaluator | Claude Code runtime (LLM-based against transcript) | shell-grep on `[STOP-GATE]` integer flags |
| Granularity | natural language ("complete v4_plan.md") | hard 0/1 gates (current_goal_complete, action_log_written, …) |
| False positives | rare; LLM evaluator is generous | frequent (any gate=0 blocks; tail-task batch posting was a common failure) |
| Bg-task awareness | works alongside subagent notifications | required manual mtime gating in fe74c26 to avoid false-blocks |
| Maintenance cost | zero | 213 lines of bash + state-file ceremony + multiple bug-fix iterations |
| Override | `/goal clear` | edit status.md by hand or set every flag to 1 |
| Visibility | inline Stop hook feedback in transcript | hidden in status.md unless user reads it |

## Decision

1. Retire `hooks/stop_self_audit.sh` and `hooks/reset_session_status.sh` (the
   status.md resetter) from active use. Scripts remain on disk for git
   history reference; no auto-registration in settings.json (already
   unregistered as of commit 1a398f1 / f716593).
2. v4 workflow relies on `/goal` for stop-gating. Users set goals via the
   `/goal` slash command at the start of a non-trivial task; clear via
   `/goal clear` if abandoning early.
3. No replacement hook needed — `/goal` covers what stop_self_audit.sh tried
   to enforce with far less brittleness.

## Open questions deferred

- Programmatic API for setting/clearing goals from a hook? (Would let
  `session_boot.sh` auto-set a goal from `workspace/<task>/goal.md`
  contents. Out of P9 scope; revisit in v5 if needed.)
- Behaviour of `/goal` under Codex compatibility layer? See P10 notes —
  Codex likely has no equivalent, so the autonomous-3-failure stop rule
  defined in `p6_workflow.md` M6 is the Codex-side fallback.
