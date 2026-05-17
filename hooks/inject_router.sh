#!/usr/bin/env bash
# inject_router.sh — UserPromptSubmit hook. State-aware router (v2.1 P15).
# Reads latest state.md, parses current_status, cats matching router_<STATUS>.md.
# Falls back to router.md when no state file (first turn / non-project dir).
# v2.7.1: prepends `[BARRY · session=<sid>]` header so the model always sees
# the authoritative sid (from hook input JSON — only race-free truth source
# per-process). AI should pass that sid to transition.sh via --sid= in
# multi-claude-per-cwd scenarios; bypasses the CURRENT_SID file race.
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

# v2.7.1: read hook input for authoritative session_id (Claude Code guarantees
# this is the active sid for the firing process). Fallback to CURRENT_SID file.
INPUT="$(cat 2>/dev/null || true)"
SID_FROM_INPUT=""
if [ -n "$INPUT" ]; then
    SID_FROM_INPUT="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi

# P36: router files read from repo via __CLAUDE_CONFIG_DIR__ (sed-substituted at deploy time).
RULES_REPO_DIR="__CLAUDE_CONFIG_DIR__/content/rules"
FALLBACK="${RULES_REPO_DIR}/router.md"

# Discover state file using session lib. PWD comes from claude-code; default cwd.
CWD="${PWD:-$(pwd)}"
STATE_FILE="$(latest_state_file "$CWD" || true)"

STATUS=""
if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
    STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
fi

ROUTER_FILE=""
if [ -n "$STATUS" ]; then
    candidate="${RULES_REPO_DIR}/router_${STATUS}.md"
    [ -f "$candidate" ] && ROUTER_FILE="$candidate"
fi
[ -z "$ROUTER_FILE" ] && ROUTER_FILE="$FALLBACK"

# v2.7.1: prepend session marker so AI can copy the sid into transition.sh calls.
if [ -n "$SID_FROM_INPUT" ]; then
    echo "[BARRY · session=${SID_FROM_INPUT}] — pass this sid to transition.sh as --sid=${SID_FROM_INPUT} (multi-claude-per-cwd safety)."
fi

# v2.8.0: inject current_goal from state.md into banner
CURRENT_GOAL=""
if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ]; then
    CURRENT_GOAL="$(grep -m1 '^current_goal:' "$STATE_FILE" 2>/dev/null | sed 's/^current_goal:[[:space:]]*//' | tr -d '"' | tr -d '\n' || true)"
fi
# v2.7.10: also check that the goal file actually exists on disk — stale paths
# (e.g. after a smoke-test workspace dir was deleted) should fall through to
# [GOAL NOT SET] instead of showing a broken banner.
if [ -n "$CURRENT_GOAL" ] && [ "$CURRENT_GOAL" != '""' ] && [ -f "${CWD}/${CURRENT_GOAL}" ]; then
    echo "[GOAL · ${CURRENT_GOAL}] still matches user's current intent? if not, run scripts/new_task.sh to write a new goal before continuing. if yes, Read goal.md again to confirm constraints still hold."
else
    if [ -n "$CURRENT_GOAL" ] && [ "$CURRENT_GOAL" != '""' ]; then
        echo "[GOAL NOT SET] (stale path ${CURRENT_GOAL} — file missing) — in PREPARE state, run: bash __CLAUDE_CONFIG_DIR__/scripts/new_task.sh --name <task_name> --goal \"...\" --constraint \"...\""
    else
        echo "[GOAL NOT SET] — in PREPARE state, run: bash __CLAUDE_CONFIG_DIR__/scripts/new_task.sh --name <task_name> --goal \"...\" --constraint \"...\""
    fi
fi

if [ -f "$ROUTER_FILE" ]; then
    cat "$ROUTER_FILE"
else
    echo "[ROUTER] no router file at $ROUTER_FILE — rerun set_claude.sh"
fi
