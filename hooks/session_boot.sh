#!/usr/bin/env bash
# session_boot.sh — UserPromptSubmit hook. Creates per-session state + action
# files under $PWD/.barry_workflow/<sid>/ if missing. Idempotent.
# v2.1 P22: per-session subdir layout.
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

INPUT="$(cat || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"
[ -z "$SID" ] && SID="$(date +%s)-noidshort"

# Heuristic: only create if .git or CLAUDE.md or workspace/ exists at $CWD.
if [ ! -d "${CWD}/.git" ] && [ ! -f "${CWD}/CLAUDE.md" ] && [ ! -d "${CWD}/workspace" ]; then
    exit 0
fi

SDIR="$(session_dir "$CWD" "$SID")"
STATE_FILE="${SDIR}/state.md"
ACTION_FILE="${SDIR}/action.md"

mkdir -p "$SDIR"

TEMPLATE_ROOT="__CLAUDE_CONFIG_DIR__/content/templates"
STATE_TPL="${TEMPLATE_ROOT}/state_template.md"
ACTION_TPL="${TEMPLATE_ROOT}/action_template.md"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DT="$(date -u +%Y-%m-%d)"

if [ ! -f "$STATE_FILE" ] && [ -f "$STATE_TPL" ]; then
    sed -e "s|__SID__|${SID}|g" -e "s|__TS__|${TS}|g" -e "s|__DATE__|${DT}|g" \
        "$STATE_TPL" > "$STATE_FILE"
fi
if [ ! -f "$ACTION_FILE" ] && [ -f "$ACTION_TPL" ]; then
    sed -e "s|__SID__|${SID}|g" -e "s|__DATE__|${DT}|g" \
        "$ACTION_TPL" > "$ACTION_FILE"
fi

exit 0
