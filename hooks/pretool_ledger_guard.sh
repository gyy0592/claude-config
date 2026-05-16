#!/usr/bin/env bash
# pretool_ledger_guard.sh — v2.5.1 (F3 fix).
#
# PreToolUse hook (matcher=*). Hard-denies Edit / Write / NotebookEdit on any
# path matching workflow_config.yaml `recording.guarded_paths` globs WHEN the
# current FSM state is NOT RECORDING.
#
# Rationale: previously the "ledger writes belong in RECORDING" rule was a
# soft "reminder" in router_EXECUTE_LOOP.md and AI routinely inlined the
# Edit in EXECUTE_LOOP (F3 in docs/fail_cases_2.5.md). This hook turns the
# soft reminder into a permissionDecision=deny mechanical fence.
#
# Path matching uses fnmatch-style globs read from yaml, NOT hardcoded names,
# so adding a new ledger file (or renaming one) only requires editing the
# yaml — no hook code change (per user L249: must be general / robust).
#
# Exit codes:
#   0 + permissionDecision allow  — path is fine OR state is RECORDING
#   0 + permissionDecision deny   — blocked; AI sees the reason and must
#                                   transition.sh NEED_RECORD first
#
# Errors swallowed — never breaks the tool call. Falls open (allow) if config
# unreadable or hook input malformed.

set -u

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-__CLAUDE_CONFIG_DIR__}"
LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
case "$TOOL" in
    Edit|Write|NotebookEdit) ;;
    *) exit 0 ;;
esac

# Pull target path from tool_input. Different tools use different keys; check
# the common ones (file_path, notebook_path).
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null || true)"
[ -z "$TARGET" ] && exit 0

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"

# Resolve current FSM state. RECORDING → allow everything.
STATE_FILE="$(latest_state_file "$CWD" 2>/dev/null || true)"
[ -z "$STATE_FILE" ] && exit 0
[ -f "$STATE_FILE" ] || exit 0
STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
[ "$STATUS" = "RECORDING" ] && exit 0
[ -z "$STATUS" ] && exit 0

# Read guarded_paths list from yaml. We parse a simple block:
#   recording:
#     guarded_paths:
#       - "workspace/bitter_lessons.md"
#       - ...
YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
[ -f "$YAML" ] || exit 0

MATCHED_GLOB="$(python3 - "$YAML" "$TARGET" "$CWD" <<'PY' 2>/dev/null
import sys, os, fnmatch, pathlib, re
yaml_path, target, cwd = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    text = pathlib.Path(yaml_path).read_text()
except Exception:
    sys.exit(0)

# Hand-rolled mini-parser for the "recording:\n  guarded_paths:\n    - X\n    - Y" block.
# Avoid pyyaml dep (matches the _session_lib.sh convention).
m = re.search(r"^recording:\s*\n((?:[ \t]+.*\n)+)", text, re.M)
if not m:
    sys.exit(0)
block = m.group(1)
mm = re.search(r"^[ \t]+guarded_paths:\s*\n((?:[ \t]+- .*\n)+)", block, re.M)
if not mm:
    sys.exit(0)
globs = []
for line in mm.group(1).splitlines():
    line = line.strip()
    if not line.startswith("- "): continue
    g = line[2:].strip().strip('"').strip("'")
    if g: globs.append(g)

# Normalise target to a relative path against cwd if applicable, AND keep absolute.
candidates = {target}
try:
    if os.path.isabs(target):
        rel = os.path.relpath(target, cwd)
        candidates.add(rel)
    else:
        candidates.add(os.path.relpath(os.path.abspath(target), cwd))
except Exception:
    pass

for g in globs:
    # Allow globs to match either rel or abs; also accept prefix match for the
    # "workspace/foo.md" case where target may be ".../workspace/foo.md".
    for cand in candidates:
        if fnmatch.fnmatch(cand, g) or cand.endswith("/" + g) or cand == g:
            print(g); sys.exit(0)
sys.exit(0)
PY
)"

if [ -n "$MATCHED_GLOB" ]; then
    REASON="ledger guard: target '$TARGET' matches recording.guarded_paths glob '$MATCHED_GLOB'. Current state=$STATUS (≠ RECORDING). Run 'bash hooks/transition.sh NEED_RECORD --reason=...' to switch into RECORDING first, then write, then BACK_TO_LOOP."
    jq -n --arg r "$REASON" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
    exit 0
fi

exit 0
