#!/bin/bash
# reset_session_status.sh — UserPromptSubmit hook
#
# Runs at the start of EVERY user turn. Manages per-session status file at:
#   $cwd/.claude_status/{session_id}_status.md
#
# Behavior:
#   - If file does NOT exist: copy template (first turn of session)
#   - If file EXISTS: reset all [STOP-GATE] items to their defaults
#     (current_goal_complete=0, action_log_written=0, six_decree_audit_done=0,
#      violations_all_recorded=1, no_abandoned_work=0)
#   - Other sections (NOTES, LONG_RUNNING_JOBS) are preserved unchanged.
#
# Stdout is empty (no injection). All work is filesystem-side.

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "default"')
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] && cwd="$PWD"

STATUS_DIR="$cwd/.claude_status"
STATUS_FILE="$STATUS_DIR/${session_id}_status.md"

TEMPLATE="__CLAUDE_CONFIG_DIR__/content/templates/status.md"

# If .claude_status/ does not exist, this project hasn't been init'd — skip silently
[ ! -d "$STATUS_DIR" ] && exit 0

# Create from template if missing
if [ ! -f "$STATUS_FILE" ] && [ -f "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$STATUS_FILE"
fi

# Reset [STOP-GATE] items to defaults
[ -f "$STATUS_FILE" ] && python3 - "$STATUS_FILE" << 'PY'
import sys, re
path = sys.argv[1]
defaults = {
    'current_goal_complete': '0',
    'action_log_written': '0',
    'six_decree_audit_done': '0',
    'violations_all_recorded': '1',
    'no_abandoned_work': '0',
}
with open(path) as f:
    content = f.read()
out = []
in_gate = False
for line in content.split('\n'):
    stripped = line.strip()
    if stripped.startswith('[STOP-GATE]'):
        in_gate = True
        out.append(line)
        continue
    if stripped.startswith('[') and in_gate:
        in_gate = False
        out.append(line)
        continue
    if in_gate:
        m = re.match(r'^(\s*)([a-z_]+):\s*\S+(\s*#.*)?$', line)
        if m and m.group(2) in defaults:
            indent = m.group(1)
            key = m.group(2)
            comment = m.group(3) or ''
            new_line = f"{indent}{key}: {defaults[key]}{comment}"
            out.append(new_line)
            continue
    out.append(line)
with open(path, 'w') as f:
    f.write('\n'.join(out))
PY

exit 0
