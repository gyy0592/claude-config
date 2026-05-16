#!/usr/bin/env bash
# pretool_state_tool_guard.sh — v2.5.5.
#
# PreToolUse hook (matcher=*). Reads yaml `state_tool_policy.<STATE>.deny_tools`
# and denies any tool call whose name is in that list when the FSM is in that
# state. permissionDecision=deny, but message is informative — AI can transition
# to a state where the tool is allowed, then retry.
#
# Pattern parallels pretool_ledger_guard.sh: yaml-driven, no per-tool hardcoding.
# Adding a new restriction = edit yaml, hook code untouched (general per L249).

set -u

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-__CLAUDE_CONFIG_DIR__}"
LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
[ -z "$TOOL" ] && exit 0

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"

STATE_FILE="$(latest_state_file "$CWD" 2>/dev/null || true)"
[ -z "$STATE_FILE" ] && exit 0
[ -f "$STATE_FILE" ] || exit 0
STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
[ -z "$STATUS" ] && exit 0

YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
[ -f "$YAML" ] || exit 0

# Parse state_tool_policy.<STATUS>.deny_tools using python (handles inline lists).
DENIED="$(STATE="$STATUS" python3 - "$YAML" "$TOOL" <<'PY' 2>/dev/null
import sys, re, os
yaml_path, tool = sys.argv[1], sys.argv[2]
state = os.environ.get("STATE","")
try:
    text = open(yaml_path).read()
except Exception:
    sys.exit(0)

# Find the state_tool_policy block.
m = re.search(r"^state_tool_policy:\s*\n((?:[ \t]+.*\n)+)", text, re.M)
if not m: sys.exit(0)
block = m.group(1)

# Within that block find the per-state subblock matching STATE.
ms = re.search(rf"^[ \t]+{re.escape(state)}:\s*\n((?:[ \t]+.*\n)+?)(?=^[ \t]{{0,2}}[A-Za-z_]|\Z)", block, re.M)
if not ms: sys.exit(0)
sub = ms.group(1)

# Extract deny_tools list. Supports inline ([A, B]) or multi-line bullets.
mt = re.search(r"deny_tools:\s*\[([^\]]+)\]", sub)
tools = []
if mt:
    tools = [t.strip().strip('"').strip("'") for t in mt.group(1).split(",") if t.strip()]
else:
    # Multi-line form: "    - X" per line under deny_tools:
    mb = re.search(r"deny_tools:\s*\n((?:[ \t]+- .*\n)+)", sub)
    if mb:
        for line in mb.group(1).splitlines():
            line = line.strip()
            if line.startswith("- "):
                tools.append(line[2:].strip().strip('"').strip("'"))

if tool in tools:
    print("HIT")
PY
)"

if [ "$DENIED" = "HIT" ]; then
    REASON="state_tool_guard: tool '$TOOL' is denied in state '$STATUS' (per workflow_config.yaml state_tool_policy.${STATUS}.deny_tools). If you genuinely need this tool, first transition to a state that allows it: bash hooks/transition.sh <event> (e.g. BOOT_DONE → PREPARE). To loosen the rule, edit the yaml."
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
