#!/usr/bin/env bash
# pretool_reflect_nag.sh — v2.5.
#
# PreToolUse hook (matcher=*). When all of these hold simultaneously:
#   (a) current_status == REFLECT (per latest state.md)
#   (b) no Agent / SendMessage invocation has been recorded in any action.md
#       under this session OR the on-disk action.md is empty of those markers
# emit a short ≤max_chars reminder via permissionDecisionReason that the
# model must spawn a rebuttal subagent before doing other work in REFLECT.
#
# Triggers on EVERY tool call so long as both conditions hold — once the
# model spawns the Agent (or transitions out of REFLECT), the nag disappears.
# Cost: ~200 chars per tool call while idle in REFLECT, which is exactly
# when the model needs the reminder most.
#
# Non-blocking (permissionDecision="allow"). errors swallowed.

set -u

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-__CLAUDE_CONFIG_DIR__}"
LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

ENABLED=true
MAX_CHARS=200
YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$YAML" "reflect_nag.enabled" 2>/dev/null || true)"
    [ -n "${v:-}" ] && ENABLED="$v"
    v="$(read_config "$YAML" "reflect_nag.max_chars" 2>/dev/null || true)"
    [ -n "${v:-}" ] && MAX_CHARS="$v"
fi
[ "$ENABLED" != "true" ] && exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"

# If the model is about to call Agent or SendMessage right now, no nag needed.
case "$TOOL" in
    Agent|SendMessage|Task) exit 0 ;;
esac

STATE_FILE="$(latest_state_file "$CWD" 2>/dev/null || true)"
[ -z "$STATE_FILE" ] && exit 0
[ -f "$STATE_FILE" ] || exit 0

STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
[ "$STATUS" = "REFLECT" ] || exit 0

# Check action.md history — has Agent/SendMessage/Task already fired?
ACTION_FILE="$(latest_action_file "$CWD" 2>/dev/null || true)"
if [ -n "$ACTION_FILE" ] && [ -f "$ACTION_FILE" ]; then
    if grep -qE 'tool_use.*"(Agent|SendMessage|Task)"|\[(SPAWN|REBUTTAL|AGENT)\]' "$ACTION_FILE" 2>/dev/null; then
        exit 0
    fi
fi

# Also check for any reflection_*.md under the session dir (sign that a
# rebuttal subagent already wrote something).
SDIR="$(dirname "$STATE_FILE")"
if ls "$SDIR"/reflection_*.md >/dev/null 2>&1; then
    exit 0
fi

MSG="REFLECT 状态：还没 spawn rebuttal subagent。除非正准备 spawn 或刚 Read reflect.md，否则下一步应当 Agent(run_in_background=true, subagent_type=general-purpose) 跑 rebuttal，不是写文件/读杂项。详见 ~/.claude/rules/states/reflect.md"
# Truncate to MAX_CHARS.
if [ "${#MSG}" -gt "$MAX_CHARS" ]; then
    MSG="${MSG:0:$((MAX_CHARS-3))}..."
fi

jq -n --arg m "$MSG" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: $m
    }
}'
exit 0
