#!/usr/bin/env bash
# inject_router.sh — UserPromptSubmit hook. State-aware router (v2.1 P15).
# Reads latest state.md, parses current_status, cats matching router_<STATUS>.md.
# Falls back to router.md when no state file (first turn / non-project dir).
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

RULES_DIR="$HOME/.claude/rules"
FALLBACK="${RULES_DIR}/router.md"

# Discover state file using session lib. PWD comes from claude-code; default cwd.
CWD="${PWD:-$(pwd)}"
STATE_FILE="$(latest_state_file "$CWD" || true)"

STATUS=""
if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
    STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
fi

ROUTER_FILE=""
if [ -n "$STATUS" ]; then
    candidate="${RULES_DIR}/router_${STATUS}.md"
    [ -f "$candidate" ] && ROUTER_FILE="$candidate"
fi
[ -z "$ROUTER_FILE" ] && ROUTER_FILE="$FALLBACK"

if [ -f "$ROUTER_FILE" ]; then
    cat "$ROUTER_FILE"
else
    echo "[ROUTER] no router file at $ROUTER_FILE — rerun set_claude.sh"
fi
