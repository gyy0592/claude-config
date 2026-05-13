#!/bin/bash
# stop_self_audit.sh — Stop hook (v2.2)
#
# Reads $cwd/.claude_status/{session_id}_status.md [STOP-GATE].
# Allows stop ONLY when all items = 1. Blocks otherwise.
#
# Exceptions (allow stop without all-1 check):
#   - Subagent (Agent tool) dispatched and not yet returned → allow stop
#     (PostToolUse:Agent will re-trigger main thread when subagent finishes).
#
# Block limit: 100 attempts per turn (was 10). Counter resets each fresh turn
# (stop_hook_active=false) and on successful stop.
#
# Block message reminds: if a background bash job is running, the AI should
# use the Monitor tool with a long timeout (e.g. 15 min) to actively wait,
# instead of trying to stop. Monitor blocks the main thread without firing
# Stop hook, allowing the AI to wait without consuming a stop attempt.

input=$(cat)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
session_id=$(echo "$input" | jq -r '.session_id // "default"')
cwd=$(echo "$input" | jq -r '.cwd // ""')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
[ -z "$cwd" ] && cwd="$PWD"

MAX_BLOCKS=100
counter_file="/tmp/stop_block_count_${session_id}"
status_dir="$cwd/.claude_status"
status_file="$status_dir/${session_id}_status.md"

# Auto-create status dir + file (same behavior as reset_session_status.sh).
# This way Stop hook is self-sufficient and never needs to complain about
# missing file — it just creates one with defaults and proceeds with checks.
mkdir -p "$status_dir" 2>/dev/null
if [ ! -f "$status_file" ]; then
    TEMPLATE="__CLAUDE_CONFIG_DIR__/content/templates/status.md"
    [ -f "$TEMPLATE" ] && cp "$TEMPLATE" "$status_file"
fi

# Fresh turn — reset counter
if [ "$stop_hook_active" = "false" ]; then
    rm -f "$counter_file"
fi

# Background-task detection (humanize-pure — parse transcript for
# toolUseResult.isAsync (subagent) AND toolUseResult.backgroundTaskId (bash bg);
# subtract task_notification completion events; lsof liveness prune).
#
# Rule (matches humanize loop-bg-tasks.sh:392-405): if ANY bg task is pending,
# ALLOW stop (exit 0). Stop in Claude Code semantics means "main thread sleeps
# until task_notification wakes it" — that IS the right action when bg work
# is in flight. No Monitor-recency check, no staleness threshold. Both kill
# false positives where freshly-dispatched tasks (Monitor not yet called) get
# falsely flagged as stale and blocked.
bg_state="none"  # none | pending | unknown
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    bg_state=$(python3 - "$transcript_path" 2>/dev/null << 'PY'
import sys, json, os
path = sys.argv[1]

launched_ids = set()
completed_ids = set()

try:
    tasks_dir = None
    try:
        slug = os.path.basename(os.path.dirname(path))
        sid = os.path.basename(path).rsplit('.jsonl', 1)[0]
        uid = os.geteuid()
        tasks_dir = f"/tmp/claude-{uid}/{slug}/{sid}/tasks"
    except Exception:
        pass

    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try: obj = json.loads(line)
            except: continue

            tur = obj.get('toolUseResult') if isinstance(obj.get('toolUseResult'), dict) else None
            if tur:
                # Launch: agent with isAsync==true, OR bash with backgroundTaskId.
                if tur.get('isAsync') is True and tur.get('agentId'):
                    launched_ids.add(tur['agentId'])
                bgid = tur.get('backgroundTaskId')
                if bgid:
                    launched_ids.add(bgid)

                # Completion (form 1, current Claude Code): agent finished result
                # has agentId + totalDurationMs (and status=="completed"). This
                # replaced system/task_notification in newer Claude Code.
                if tur.get('agentId') and (
                    tur.get('totalDurationMs') is not None
                    or tur.get('status') == 'completed'
                ):
                    completed_ids.add(tur['agentId'])

            # Completion (form 2, legacy SDK): system/task_notification event.
            if obj.get('type') == 'system' and obj.get('subtype') == 'task_notification':
                tid = obj.get('task_id')
                if tid: completed_ids.add(tid)

            # Completion (form 3, very old): queue-operation enqueue containing
            # <task-notification><task-id>...</task-id> in content.
            if obj.get('type') == 'queue-operation' and obj.get('operation') == 'enqueue':
                content = obj.get('content', '')
                if isinstance(content, str) and '<task-notification>' in content:
                    import re
                    for m in re.findall(r'<task-id>([^<]+)</task-id>', content):
                        completed_ids.add(m)

    pending = launched_ids - completed_ids

    # Liveness prune is SKIPPED for agent tasks: Claude Code stores agent
    # .output as a symlink to subagents/<id>.jsonl, which is opened/closed
    # per write, so lsof reports zero holders even while the agent is alive.
    # We rely purely on (launched - completed) sets — Claude Code's own
    # completion result event is authoritative.
    #
    # For Bash backgroundTaskId tasks the underlying shell process DOES hold
    # the output, but distinguishing agent IDs vs bash IDs in this scope is
    # not worth the code; the completion set is sufficient for both.

    print('pending' if pending else 'none')
except Exception:
    print('unknown')
PY
)
fi

# Humanize-pure: bg pending → unconditional allow stop. The natural pause is
# "main thread sleeps until task_notification wakes it". Skipping the gate
# here is intentional — gate audit will fire again on the next wake-up.
if [ "$bg_state" = "pending" ]; then
    rm -f "$counter_file"
    exit 0
fi
# bg_state == "none" → fall through to normal [STOP-GATE] check
# bg_state == "unknown" → fall through (don't trust transcript; do gate)

# Check if any [STOP-GATE] row is still 0. Accepts 1 (followed) and NA.
has_zero=0
if [ -f "$status_file" ]; then
    if awk '
        /^\[STOP-GATE\]/ { in_gate=1; next }
        /^\[/ && !/^\[STOP-GATE\]/ { in_gate=0; next }
        in_gate && /^[a-z0-9_]+:/ {
            line = $0; sub(/#.*/, "", line); gsub(/[ \t]+$/, "", line)
            ci = index(line, ":"); val = substr(line, ci + 1); gsub(/[ \t]+/, "", val)
            if (val == "0") { found=1 }
        }
        END { exit found ? 0 : 1 }
    ' "$status_file"; then
        has_zero=1
    fi
fi

# All pass — allow stop
if [ "$has_zero" = "0" ]; then
    rm -f "$counter_file"
    exit 0
fi

# Increment counter
count=$(cat "$counter_file" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$counter_file"

# Hit MAX_BLOCKS — give up to prevent infinite loop
if [ "$count" -ge "$MAX_BLOCKS" ]; then
    rm -f "$counter_file"
    exit 0
fi

# Build failure description (only [STOP-GATE]-zero path reaches here; bg-pending
# already exited above with stop allowed)
if [ "$has_zero" = "1" ]; then
    failed_section="Some [STOP-GATE] items in $status_file are still 0. Open the file, fill each with 1 / 0 / NA + reason after '#', then stop."
else
    failed_section="State bug. Check $status_file."
fi

python3 - "$count" "$MAX_BLOCKS" "$failed_section" "$status_file" << 'PYEOF'
import json, sys
count, max_b, failed, sfile = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
reason = f"""Stop BLOCKED (attempt {count}/{max_b}). {failed}

Quick checks:
  - Authorized to execute? If yes, execute, don't re-ask.
  - Completed every {sfile} [STOP-GATE] row with reason after '#'?
  - Background bash pending? Use Monitor (15min) instead of stopping.
  - Subagent pending? Stop is allowed automatically.

After {max_b} blocks the hook gives up; bypass surfaces in next turn audit."""
print(json.dumps({"decision": "block", "reason": reason}))
PYEOF
