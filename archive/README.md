# archive/

Dormant code preserved for possible future revival. Files here are **not**
deployed by `set_claude.sh` (which uses an explicit hook list, not a glob).

## hooks/stop_self_audit.sh

Last live at commit `fe74c26` (2026-05-12), removed by `10ab2c0` (v2.1 P29
"purge v1 residuals") because it depended on the old `$cwd/.claude_status/`
infrastructure that v2 retired.

**What it does** (still useful, FSM-orthogonal):

- Reads the session transcript JSONL on every Stop event.
- Counts launched bg task IDs (`toolUseResult.isAsync && agentId`, or
  `toolUseResult.backgroundTaskId`) minus completed IDs (three formats:
  finished result with `totalDurationMs` / legacy `task_notification` system
  event / very old `queue-operation` enqueue with `<task-notification>` content).
- For each still-pending task, checks `/tmp/claude-<uid>/<slug>/<sid>/tasks/<tid>.output`
  mtime. If activity within last 15 min → still pending → allow stop (main
  thread sleeps until `task_notification` wakes it). If silent ≥ 15 min →
  drop from pending list (stale/stuck).
- If anything still active → `exit 0` (allow stop).
- Otherwise → fall through to STOP-GATE check (this part depends on the
  retired `.claude_status/` system and would need rewrite to use v2's
  `.barry_workflow/<sid>/state.md` if revived).

**To revive against v2**:

1. Strip the `.claude_status/[STOP-GATE]` block (lines ~160-213). Replace
   with whatever v2 gate logic you want (or omit — bg-only behavior is also
   useful standalone).
2. Add to `set_claude.sh` line 241 hook list.
3. Register a `Stop` event hook entry in `~/.claude/settings.json` (see
   `hooks/state_enforce.sh` registration as template).
4. Optionally make the 15-min threshold a `workflow_config.yaml` knob.
