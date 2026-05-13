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

# Exception: if a subagent (Agent tool) is dispatched and pending return,
# allow stop (no block) so main thread can idle and be re-triggered.
agent_pending=0
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    agent_pending=$(python3 - "$transcript_path" 2>/dev/null << 'PY'
import sys, json
path = sys.argv[1]
uses, results = set(), set()
try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            t = obj.get('type', '')
            msg = obj.get('message', {})
            content = msg.get('content', []) if isinstance(msg, dict) else []
            if not isinstance(content, list):
                continue
            if t == 'assistant':
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'tool_use' and c.get('name') == 'Agent':
                        uses.add(c.get('id'))
            elif t == 'user':
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'tool_result':
                        results.add(c.get('tool_use_id'))
    pending = uses - results
    print(1 if pending else 0)
except Exception:
    print(0)
PY
)
fi

if [ "$agent_pending" = "1" ]; then
    rm -f "$counter_file"
    exit 0
fi

# Exception 2: bg bash job state check via [LONG_RUNNING_JOBS] in status.md.
#   - all running entries have last_monitor < 30 min ago → AI is monitoring
#     properly, allow stop
#   - any running entry has last_monitor > 30 min ago (or missing) → STALE,
#     possibly stuck (until-loop / freeze). Block + remind to use Monitor or
#     KillBash to recover.
#   - no running entries → fall through to normal [STOP-GATE] check
bg_state="none"  # none | fresh | stale
if [ -f "$status_file" ]; then
    bg_state=$(python3 - "$status_file" 2>/dev/null << 'PY'
import sys, re
from datetime import datetime, timezone, timedelta
path = sys.argv[1]
threshold = datetime.now(timezone.utc) - timedelta(minutes=30)
in_jobs = False
has_running = False
any_stale = False
with open(path) as f:
    for raw in f:
        line = raw.rstrip()
        stripped = line.strip()
        if stripped.startswith('[LONG_RUNNING_JOBS]'):
            in_jobs = True; continue
        if stripped.startswith('[') and in_jobs:
            in_jobs = False; continue
        if not in_jobs: continue
        if re.search(r'status\s*[:=]\s*running', line):
            has_running = True
            m = re.search(r'last_monitor\s*[:=]\s*(\S+)', line)
            if not m:
                any_stale = True; continue
            ts = m.group(1).rstrip(',;')
            for fmt in ('%Y-%m-%dT%H:%M:%SZ','%Y-%m-%dT%H:%MZ','%Y-%m-%d %H:%M UTC','%Y-%m-%d %H:%M:%S UTC'):
                try:
                    dt = datetime.strptime(ts, fmt).replace(tzinfo=timezone.utc); break
                except ValueError: dt = None
            if dt is None: any_stale = True; continue
            if dt < threshold: any_stale = True
if not has_running: print('none')
elif any_stale: print('stale')
else: print('fresh')
PY
)
fi

if [ "$bg_state" = "fresh" ]; then
    rm -f "$counter_file"
    exit 0
fi
# bg_state == "stale" → fall through to block (with stale-specific reminder)
# bg_state == "none" → fall through to normal [STOP-GATE] check

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
    failed_section="⚠️ A background job in [LONG_RUNNING_JOBS] has status=running but its
last_monitor timestamp is > 30 minutes old (or missing). This may indicate:
  - The job is stuck in an infinite loop (until, while true, etc.)
  - The job silently exited without you noticing
  - You forgot to update last_monitor after the most recent check

DO NOT just stop. First: call Monitor(bash_id, timeout=15m) to fetch fresh output.
If output flowing → update last_monitor=<UTC now>, then stop will be allowed.
If job hung → KillBash + update status=failed, then stop allowed.
After resolution, you may stop normally."
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
