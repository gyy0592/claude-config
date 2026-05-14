#!/usr/bin/env bash
# session_boot.sh — UserPromptSubmit hook. Creates per-session state + action
# files under $PWD/.barry_workflow/ if missing. Idempotent. No-ops if templates
# can't be found (deploy not yet run).
set -euo pipefail

# Hook input (JSON on stdin); cwd from $PWD, session id from input.
INPUT="$(cat || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"
[ -z "$SID" ] && SID="$(date +%s)-noidshort"

STATE_DIR="${CWD}/.barry_workflow"
STATE_FILE="${STATE_DIR}/state_${SID}.md"
ACTION_FILE="${STATE_DIR}/action_${SID}.md"

# Don't create anything outside a git-tracked / claude-aware project root.
# Heuristic: only create if .git or CLAUDE.md or workspace/ exists at $CWD.
if [ ! -d "${CWD}/.git" ] && [ ! -f "${CWD}/CLAUDE.md" ] && [ ! -d "${CWD}/workspace" ]; then
    exit 0
fi

mkdir -p "$STATE_DIR"

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

# Silent on success; UserPromptSubmit hooks should not emit unless adding context.
exit 0
