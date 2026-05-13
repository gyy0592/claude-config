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
status_file="$cwd/.claude_status/${session_id}_status.md"

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

# Parse [STOP-GATE] zero items
zero_items=""
status_missing=0
if [ ! -f "$status_file" ]; then
    status_missing=1
else
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
if [ "$status_missing" = "0" ] && [ -z "$zero_items" ]; then
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
if [ "$status_missing" = "1" ]; then
    failed_section="Status file $status_file does NOT exist. The UserPromptSubmit hook should have created it; if it didn't, run init_corporal.sh in $cwd (creates .claude_status/) and re-send a message."
else
    failed_section="STOP-GATE items NOT YET satisfied (each must = 1):
${zero_items}

Update $status_file: set each failing item to 1 ONLY when truly done.
Flipping without doing the work = Decree 2 fraud."
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
