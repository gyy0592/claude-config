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

# Parse [STOP-GATE] zero items (file was auto-created above if missing)
zero_items=""
if [ -f "$status_file" ]; then
    zero_items=$(awk '
        /^\[STOP-GATE\]/ { in_gate=1; next }
        /^\[/ && !/^\[STOP-GATE\]/ { in_gate=0; next }
        in_gate && /^[a-z_]+:/ {
            sub(/#.*/, "")
            gsub(/[ \t]+$/, "")
            ci = index($0, ":")
            key = substr($0, 1, ci - 1)
            val = substr($0, ci + 1)
            gsub(/[ \t]+/, "", val)
            if (val == "0") print "  - " key " = 0"
        }
    ' "$status_file")
fi

# All pass — allow stop
if [ -z "$zero_items" ]; then
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
    failed_section="⚠️ A background task (Agent run_in_background or Bash run_in_background)
is still pending — no task_notification completion event seen — AND no Monitor
tool call has been made in the last 30 minutes (transcript timestamps).

Possible causes:
  - The task is stuck in an infinite loop (until, while true, etc.)
  - The task silently exited without emitting completion
  - You forgot to call Monitor recently to check progress

DO NOT just stop. First: call the Monitor tool (timeout 15 min) on the pending
bash_id to fetch fresh output. If output flowing → recent Monitor call updates
the staleness window → next stop will be allowed. If task hung → KillBash to
recover. After Monitor or Kill, you may stop normally."
elif [ -n "$zero_items" ]; then
    failed_section="STOP-GATE items NOT YET satisfied (each must = 1):
${zero_items}

Update $status_file: set each failing item to 1 ONLY when truly done.
Flipping without doing the work = Decree 2 fraud."
else
    failed_section="Stop attempted but no obvious reason in status.md. Possibly a state bug. Re-check $status_file."
fi

python3 - "$count" "$MAX_BLOCKS" "$failed_section" "$status_file" << 'PYEOF'
import json, sys
count, max_b, failed, sfile = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
reason = f"""Stop BLOCKED (attempt {count}/{max_b}).

{failed}

Items meaning:
  current_goal_complete    1 = goal in your "Current goal:" line is genuinely complete
                               (retest 3-Qs passed for hands-on; cited evidence for Q&A)
  action_log_written       1 = corporal_action.md (or soldier_action.md if Private) has
                               an entry written this turn
  six_decree_audit_done    1 = REFLECT-A 6-row table written this turn
  violations_all_recorded  1 = no unrecorded confessions; if you said "I broke X", you
                               wrote W-XXX to __CLAUDE_CONFIG_DIR__/content/templates/global_rules/violation.md
                               AND mirrored in action.md
  no_abandoned_work        1 = no mid-flight work being skipped

⚠️ If you have a background bash job running (sbatch / training / long command), DO NOT
keep trying to stop. Use the Monitor tool with a long timeout (e.g. 15 min) on the
bash_id to actively wait for output. Monitor blocks the main thread WITHOUT firing
this Stop hook, lets you wait cheaply (token-light), and naturally resumes when the
job emits output or finishes. Record each Monitor check in {sfile}'s [LONG_RUNNING_JOBS] section.

⚠️ If you dispatched a subagent (Agent tool), the Stop hook will AUTOMATICALLY allow
your stop so the subagent can run; PostToolUse:Agent re-triggers your main thread when
the subagent returns. You don't need to do anything special.

After {max_b} blocks the hook gives up and lets you stop, but the next turn's
REFLECT-A D6 row will record this willful bypass."""
print(json.dumps({"decision": "block", "reason": reason}))
PYEOF
