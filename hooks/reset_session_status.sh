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

# Auto-create .claude_status/ if missing (no need to wait for init_corporal.sh)
mkdir -p "$STATUS_DIR" 2>/dev/null || exit 0

# Create from template if missing
if [ ! -f "$STATUS_FILE" ] && [ -f "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$STATUS_FILE"
fi

# Reset [STOP-GATE] items to defaults
# 1. Reset [STOP-GATE] defaults
# 2. Auto-rebuild [LONG_RUNNING_JOBS] from filesystem
#    (find alive .output files in any session's tasks dir for this cwd's slug,
#     lsof to verify alive, list bash_id + session + UTC discovery time)
[ -f "$STATUS_FILE" ] && SESSION_ID="$session_id" CWD="$cwd" python3 - "$STATUS_FILE" << 'PY'
import sys, re, os, subprocess, glob
from datetime import datetime, timezone
path = sys.argv[1]
session_id = os.environ.get('SESSION_ID', '')
cwd = os.environ.get('CWD', '')

# Reset ALL [STOP-GATE] items to "0" generically (regex match).
# AI must re-evaluate every item per turn and provide evidence.
defaults = None  # signal: reset every matching key to "0"

# Find all alive bg tasks (any session for this cwd's slug)
def find_alive_tasks():
    uid = os.geteuid()
    # Compute slug from cwd path
    slug = cwd.replace('/', '-')
    pattern = f"/tmp/claude-{uid}/{slug}/*/tasks/*.output"
    alive = []
    for f in glob.glob(pattern):
        try:
            r = subprocess.run(['lsof', '-t', f], capture_output=True, timeout=2)
            if r.returncode == 0 and r.stdout.strip():
                # extract bash_id + session_id from path
                parts = f.rstrip('.output').split('/')
                bash_id = parts[-1]
                sess = parts[-3]
                alive.append((bash_id, sess, f))
        except Exception:
            pass
    return alive

alive_tasks = find_alive_tasks()
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%MZ')

with open(path) as f:
    content = f.read()

# Build new [LONG_RUNNING_JOBS] section content (replace whole section)
def build_jobs_section():
    lines = ['[LONG_RUNNING_JOBS]']
    lines.append('# Auto-rebuilt by reset_session_status.sh every turn — alive tasks discovered via lsof.')
    if not alive_tasks:
        lines.append('# (none alive)')
    else:
        for bid, sess, _ in alive_tasks:
            tag = ' (this session)' if sess == session_id else ' (cross-session)'
            lines.append(f'job-{bid}: bash_id={bid} session={sess} status=running last_discovered={now}{tag}')
    lines.append('')
    return lines

# Reset [STOP-GATE] + replace [LONG_RUNNING_JOBS] section
out = []
in_gate = False
in_jobs = False
jobs_inserted = False
for line in content.split('\n'):
    stripped = line.strip()
    # Detect section starts
    if stripped.startswith('[STOP-GATE]'):
        in_gate = True; in_jobs = False
        out.append(line); continue
    if stripped.startswith('[LONG_RUNNING_JOBS]'):
        in_gate = False; in_jobs = True
        out.extend(build_jobs_section()); jobs_inserted = True
        continue
    if stripped.startswith('['):
        in_gate = False
        if in_jobs:
            in_jobs = False  # exiting jobs section; preserve this header
        out.append(line); continue
    # Inside sections
    if in_jobs:
        continue  # skip old jobs lines; we already wrote the new section
    if in_gate:
        m = re.match(r'^(\s*)([a-z0-9_]+):\s*\S+(\s*#.*)?$', line)
        if m:
            indent = m.group(1); key = m.group(2); comment = m.group(3) or ''
            out.append(f"{indent}{key}: 0{comment}")
            continue
    out.append(line)

# If file had no [LONG_RUNNING_JOBS] section at all, append one
if not jobs_inserted:
    out.append('')
    out.extend(build_jobs_section())

with open(path, 'w') as f:
    f.write('\n'.join(out))
PY

exit 0
