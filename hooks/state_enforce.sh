#!/usr/bin/env bash
# state_enforce.sh — PostToolUse hook (matcher=*). v2.1 P16.
# Reads current FSM state, checks if the just-completed tool was allowed in
# that state, emits a stderr warning if not. NON-BLOCKING (exit 0 always).
# PostToolUse is informational; no permission decision needed.
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

INPUT="$(cat || true)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"

STATE_FILE="$(latest_state_file "$CWD" || true)"
[ -z "$STATE_FILE" ] && exit 0
[ ! -f "$STATE_FILE" ] && exit 0

STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
[ -z "$STATUS" ] && exit 0

warn() {
    # v2.7 fix: previous version assumed PostToolUse stderr was visible to the
    # model — false for Claude Code (debug log only). Now uses JSON envelope's
    # hookSpecificOutput.additionalContext (the only Pre/PostToolUse path that
    # actually surfaces text into the model's context).
    msg="[state_enforce] $STATUS state — $1 — Are you sure you're in the right state for this? If not, consider 'bash ~/.claude/hooks/transition.sh <event>' before retrying."
    jq -n --arg m "$msg" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $m
        }
    }'
    exit 0
}

# Bash command is a "mutator" if it touches files.
is_bash_mutator() {
    printf '%s' "$CMD" | grep -qE '(^|[[:space:]/])(rm|mv|cp|sed -i|tee)([[:space:]]|$)|>>?[[:space:]]*[^&]|/transition\.sh' && return 1 # transition.sh itself is fine, exclude
    printf '%s' "$CMD" | grep -qE '(^|[[:space:]/])(rm|mv|sed -i|tee)([[:space:]]|$)|^[^|&]*>>?[[:space:]]'
}

# Coarser: is this a bash mutator regardless of the transition.sh carve-out?
bash_is_mutator() {
    # exclude transition.sh invocations and read-only commands
    case "$CMD" in
        *transition.sh*|*prepare_helper.sh*|*execute_loop_audit.sh*) return 1 ;;
    esac
    printf '%s' "$CMD" | grep -qE '(^|[[:space:];&|])(rm|mv|sed -i|tee )|[^>]>[^&]|>>'
}

case "$STATUS" in
    REFLECT)
        case "$TOOL" in
            Edit|Write|NotebookEdit)
                warn "$TOOL not allowed; defer mutations until 'transition.sh REFLECT_DONE'."
                ;;
            Bash)
                if bash_is_mutator; then
                    warn "Bash mutator '$(printf '%s' "$CMD" | head -c 60)' — defer until REFLECT_DONE."
                fi
                ;;
        esac
        ;;
    PREPARE)
        case "$TOOL" in
            Edit|Write|NotebookEdit)
                warn "$TOOL discouraged in PREPARE — finish PREPARE_DONE before executing."
                ;;
        esac
        ;;
    BOOT)
        case "$TOOL" in
            Read|Glob|Grep) ;;
            Bash)
                case "$CMD" in
                    *transition.sh*|ls*|cat*|pwd*) ;;
                    *) warn "Bash '$(printf '%s' "$CMD" | head -c 60)' — BOOT allows only Read/Glob/Grep + transition.sh/ls/cat." ;;
                esac
                ;;
            *)
                warn "$TOOL not allowed in BOOT; only Read/Glob/Grep + transition.sh/ls/cat."
                ;;
        esac
        ;;
    RECORDING)
        # Ledger writes / action.md append allowed; arbitrary code/source mutations discouraged.
        case "$TOOL" in
            Edit|Write|NotebookEdit)
                case "$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" in
                    */workspace/*|*/.barry_workflow/*|*/action_*.md) ;;
                    *) warn "$TOOL on non-ledger file in RECORDING — only workspace/*.md or .barry_workflow/action*.md expected." ;;
                esac
                ;;
        esac
        ;;
    END)
        # Read-only summary state.
        case "$TOOL" in
            Read|Glob|Grep) ;;
            Bash)
                case "$CMD" in
                    *transition.sh*|ls*|cat*|grep*|pwd*) ;;
                    *) warn "Bash '$(printf '%s' "$CMD" | head -c 60)' — END allows only Read/Bash(ls|cat|grep)." ;;
                esac
                ;;
            *)
                warn "$TOOL not allowed in END; session is closing (read-only summary)."
                ;;
        esac
        ;;
    EXECUTE_LOOP)
        # All tools allowed; no warnings here (intentional).
        :
        ;;
esac

exit 0
