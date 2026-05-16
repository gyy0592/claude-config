#!/usr/bin/env bash
# state_keepalive.sh — v2.5.3.
#
# Pre/PostToolUse hook (matcher=*). Fires on EVERY tool call (pre AND post)
# and emits one ultra-short line reminding the model what FSM state it's
# currently in, with a soft "is this the right state for this?" reflection
# prompt. Does NOT enforce, does NOT block, does NOT decide for the AI —
# just keeps the state-machine concept alive in the rolling context window
# so the AI doesn't forget that transition.sh is a thing it has to do.
#
# Output (≈80 chars):
#   [STATE=<X>] right state for this tool? if work is done, transition.sh <event>.
#
# Goal: every tool call adds this line. Cheap (~80 chars * N tool calls)
# but ensures `transition` is never out-of-context.
#
# Non-blocking. Errors swallowed. allow.

set -u

LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"

STATE_FILE="$(latest_state_file "$CWD" 2>/dev/null || true)"
[ -z "$STATE_FILE" ] && exit 0
[ -f "$STATE_FILE" ] || exit 0

STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
[ -z "$STATUS" ] && exit 0

# Map state -> the canonical exit event for the soft hint at the tail.
case "$STATUS" in
    BOOT)         NEXT="BOOT_DONE" ;;
    PREPARE)      NEXT="PREPARE_DONE" ;;
    REFLECT)      NEXT="REFLECT_DONE" ;;
    EXECUTE_LOOP) NEXT="EXECUTE_EXIT (or NEED_RECORD if mid-task ledger)" ;;
    RECORDING)    NEXT="RECORD_DONE (or BACK_TO_LOOP if mid-task)" ;;
    END)          NEXT="(none — END is terminal; RESET_TO_BOOT for new task)" ;;
    *)            NEXT="<event>" ;;
esac

MSG="[STATE=$STATUS] right state for this tool? if work for $STATUS is done, run transition.sh $NEXT."

# v2.7 fix: use additionalContext, NOT permissionDecisionReason. The latter
# is only shown to the model when permissionDecision is "deny" or "ask";
# on "allow" it goes only to the debug log, so the AI never sees it. Cost
# us many hours of "AI ignores STATE reminders" debugging. See docs:
# https://code.claude.com/docs/en/hooks — "additionalContext field is
# wrapped in a system reminder and inserted into the conversation".
if [ "$EVENT" = "PreToolUse" ]; then
    jq -n --arg m "$MSG" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            additionalContext: $m
        }
    }'
else
    jq -n --arg m "$MSG" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $m
        }
    }'
fi
exit 0
