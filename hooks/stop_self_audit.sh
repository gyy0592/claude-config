#!/bin/bash
# stop_self_audit.sh — Stop hook (v2 status.md-based gate)
#
# Strategy:
#   1. Find $PWD/.claude_status/status.md (cwd comes from stdin JSON).
#   2. Parse [STOP-GATE] section: every "key: value" line must have value=1.
#   3. Any value=0 → block + list what's wrong.
#   4. Per-session counter in /tmp limits to 10 blocks per turn; after that exit 0.
#   5. If status.md missing → block + tell AI to run init_corporal.sh.

input=$(cat)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
session_id=$(echo "$input" | jq -r '.session_id // "default"')
cwd=$(echo "$input" | jq -r '.cwd // ""')

if [ -z "$cwd" ]; then
    cwd="$PWD"
fi

MAX_BLOCKS=10
counter_file="/tmp/stop_block_count_${session_id}"
status_file="$cwd/.claude_status/status.md"

# Fresh turn (1st stop attempt) — reset counter
if [ "$stop_hook_active" = "false" ]; then
    rm -f "$counter_file"
fi

# Helper: extract zero-valued items from [STOP-GATE] section
zero_items=""
status_missing=0

if [ ! -f "$status_file" ]; then
    status_missing=1
else
    # Awk extracts lines between [STOP-GATE] and the next [SECTION] header
    # Then matches "key: value" where value (first word after :) is "0"
    zero_items=$(awk '
        /^\[STOP-GATE\]/ { in_gate=1; next }
        /^\[/ && !/^\[STOP-GATE\]/ { in_gate=0; next }
        in_gate && /^[a-z_]+:/ {
            # Strip inline comment
            sub(/#.*/, "")
            # Trim
            gsub(/[ \t]+$/, "")
            # Get key and value
            colon_idx = index($0, ":")
            key = substr($0, 1, colon_idx - 1)
            val = substr($0, colon_idx + 1)
            gsub(/[ \t]+/, "", val)
            if (val == "0") {
                print "  - " key " = 0"
            }
        }
    ' "$status_file")
fi

# All items pass? Allow stop.
if [ "$status_missing" = "0" ] && [ -z "$zero_items" ]; then
    rm -f "$counter_file"
    exit 0
fi

# Increment block counter
count=$(cat "$counter_file" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$counter_file"

# Hit limit → give up (AI willfully bypassed; next turn's REFLECT-A will catch it)
if [ "$count" -ge "$MAX_BLOCKS" ]; then
    rm -f "$counter_file"
    exit 0
fi

# Build reason text
if [ "$status_missing" = "1" ]; then
    failed_section="Status file $status_file does NOT exist. Run init_corporal.sh first, OR create .claude_status/status.md manually with the template at content/templates/status.md."
else
    failed_section="Status gate items NOT YET satisfied (each must = 1):\n${zero_items}\n\nUpdate $status_file: set each failing item to 1 ONLY when truly done. Do NOT just flip the value — actually do the work first."
fi

# Emit JSON block reason
python3 - "$count" "$MAX_BLOCKS" "$failed_section" << 'PYEOF'
import json, sys
count, max_b, failed = sys.argv[1], sys.argv[2], sys.argv[3]
reason = f"""Stop BLOCKED (attempt {count}/{max_b}). Your .claude_status/status.md [STOP-GATE] is not all 1s yet.

{failed}

Items meaning:
  current_goal_complete    1 = goal in your "Current goal:" line is genuinely complete
                               (retest 3-Qs passed for hands-on; cited evidence for Q&A)
  action_log_written       1 = corporal_action.md (or soldier_action.md if Private) has
                               an entry written this turn
  six_decree_audit_done    1 = REFLECT-A 6-row table written this turn (D1..D6 each with
                               Followed Y/N + evidence)
  violations_all_recorded  1 = no "I broke X" confessions left unrecorded; if you confessed,
                               you wrote W-XXX to /home/yguo173/Programs/claude-config/content/templates/global_rules/violation.md
                               AND mirrored in action.md
  no_abandoned_work        1 = no mid-flight work being skipped; either complete or
                               explicitly handed back to Commander

After {max_b} blocks the hook gives up and lets you stop, but the next turn's
REFLECT-A D6 row will record this willful bypass.

Fix the failing items honestly. Do NOT flip values without doing the work — that
is Decree 2 fraud."""
print(json.dumps({"decision": "block", "reason": reason}))
PYEOF
