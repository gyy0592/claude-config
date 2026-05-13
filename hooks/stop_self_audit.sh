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

# Background-task detection (humanize-style — parse transcript for
# toolUseResult.isAsync (subagent) AND toolUseResult.backgroundTaskId (bash bg);
# subtract task_notification completion events).
#
# 30-min staleness: among pending bg tasks, find the LATEST Monitor tool_use
# call timestamp on any pending bash_id. If > 30 min ago (or no Monitor call
# ever) → STALE (likely until-loop / freeze) → block + remind.
# Else → FRESH → allow stop (AI is monitoring properly; PostToolUse:Agent
# or natural completion will re-trigger).
bg_state="none"  # none | fresh | stale | unknown
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    bg_state=$(python3 - "$transcript_path" 2>/dev/null << 'PY'
import sys, json, re
from datetime import datetime, timezone, timedelta
path = sys.argv[1]
threshold = datetime.now(timezone.utc) - timedelta(minutes=30)

launched_ids = set()  # bg task ids that were launched
completed_ids = set()  # bg task ids that completed (task_notification)
last_monitor_ts = None  # latest Monitor tool_use timestamp

def parse_ts(s):
    if not s: return None
    s = s.rstrip('Z')
    for fmt in ('%Y-%m-%dT%H:%M:%S.%f','%Y-%m-%dT%H:%M:%S','%Y-%m-%dT%H:%M'):
        try:
            return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None

try:
    import os
    # For liveness probe: derive /tmp/claude-<uid>/<slug>/<sid>/tasks/<id>.output
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
                if tur.get('isAsync') is True and tur.get('agentId'):
                    launched_ids.add(tur['agentId'])
                bgid = tur.get('backgroundTaskId')
                if bgid:
                    launched_ids.add(bgid)

            if obj.get('type') == 'system' and obj.get('subtype') == 'task_notification':
                tid = obj.get('task_id')
                if tid: completed_ids.add(tid)

            t = obj.get('type', '')
            msg = obj.get('message', {})
            content = msg.get('content', []) if isinstance(msg, dict) else []
            if t == 'assistant' and isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'tool_use' and c.get('name') == 'Monitor':
                        ts = parse_ts(obj.get('timestamp', ''))
                        if ts and (last_monitor_ts is None or ts > last_monitor_ts):
                            last_monitor_ts = ts

    pending = launched_ids - completed_ids

    # LIVENESS PROBE — humanize-style via lsof.
    # The .output file persists after a task completes; we need a stronger
    # check. If no process holds the output file open (lsof returns nothing),
    # the task is dead even without explicit task_notification.
    if pending and tasks_dir and os.path.isdir(tasks_dir):
        import subprocess
        alive = set()
        for tid in pending:
            output_file = os.path.join(tasks_dir, f"{tid}.output")
            if not os.path.exists(output_file):
                continue  # file gone → task dead → not pending
            try:
                # lsof -t prints PIDs of processes holding the file open
                r = subprocess.run(['lsof', '-t', output_file], capture_output=True, timeout=2)
                if r.returncode == 0 and r.stdout.strip():
                    alive.add(tid)  # at least 1 process has it open → alive
                # else: file exists but no process holds it → dead → drop
            except Exception:
                alive.add(tid)  # lsof error: fail open (treat as alive)
        pending = alive

    if not pending:
        print('none')
    elif last_monitor_ts is None or last_monitor_ts < threshold:
        print('stale')
    else:
        print('fresh')
except Exception:
    print('unknown')
PY
)
fi

if [ "$bg_state" = "fresh" ]; then
    rm -f "$counter_file"
    exit 0
fi
# bg_state == "stale" → block with stale-specific reminder (fall through)
# bg_state == "none" → fall through to normal [STOP-GATE] check
# bg_state == "unknown" → fall through (don't trust; do normal gate)

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
if [ "$has_zero" = "0" ] && [ "$bg_state" != "stale" ]; then
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

# Build failure description
if [ "$bg_state" = "stale" ]; then
    failed_section="Background task pending; no Monitor in last 30 min. Call Monitor (15min) or KillBash before stopping."
elif [ "$has_zero" = "1" ]; then
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
