#!/usr/bin/env bash
# pretooluse_short_nudge.sh — PreToolUse hook (matcher=*).
# Emits at most one ≤100-char reminder per tool call. Strictly informational
# (permissionDecision="allow") to avoid blocking; no policy text inlined.
# Counters live under $PWD/.barry_workflow/nudge_counters.json (best-effort).
#
# Tunables (v2.2 P35): read from content/rules/workflow_config.yaml at runtime.
#   pretool_nudge.read_threshold  → "$cnt -ge $READ_THRESHOLD" check below
#   pretool_nudge.max_chars       → truncation in nudge()
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

# P35: resolve yaml path via __CLAUDE_CONFIG_DIR__ (sed-substituted at deploy time).
_YAML="__CLAUDE_CONFIG_DIR__/content/rules/workflow_config.yaml"
READ_THRESHOLD="$(read_config "$_YAML" pretool_nudge.read_threshold 2>/dev/null || true)"
if [ -z "$READ_THRESHOLD" ]; then
    echo "[hook] config read failed for pretool_nudge.read_threshold, using default=3" >&2
    READ_THRESHOLD=3
fi
MAX_CHARS="$(read_config "$_YAML" pretool_nudge.max_chars 2>/dev/null || true)"
if [ -z "$MAX_CHARS" ]; then
    MAX_CHARS=100
fi

INPUT="$(cat || true)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"
# Resolve session dir: prefer SID from input, else fall back to latest session.
if [ -n "$SID" ] && [ -d "$(session_dir "$CWD" "$SID")" ]; then
    CTR_DIR="$(session_dir "$CWD" "$SID")"
else
    CTR_DIR="$(latest_session_dir "$CWD" || true)"
fi
[ -z "$CTR_DIR" ] && CTR_DIR="${CWD}/.barry_workflow"
CTR="${CTR_DIR}/nudge_counters.json"
[ -d "$CTR_DIR" ] && [ ! -f "$CTR" ] && echo '{}' > "$CTR" 2>/dev/null || true

bump() {
    local key="$1"
    if command -v jq >/dev/null 2>&1 && [ -w "$CTR" ]; then
        local new
        new=$(jq -c --arg k "$key" '.[$k] = (.[$k] // 0) + 1' "$CTR" 2>/dev/null || echo '{}')
        printf '%s' "$new" > "$CTR" 2>/dev/null || true
        jq -r --arg k "$key" '.[$k] // 0' "$CTR" 2>/dev/null
    else
        echo 1
    fi
}

nudge() {
    # Emits JSON envelope with allow + a short reason. Max $MAX_CHARS enforced.
    local msg="$1"
    [ "${#msg}" -gt "$MAX_CHARS" ] && msg="${msg:0:$((MAX_CHARS-3))}..."
    jq -n --arg m "$msg" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            permissionDecisionReason: $m
        }
    }'
    exit 0
}

case "$TOOL" in
    Read|Grep|Glob)
        cnt=$(bump "read")
        if [ "${cnt:-0}" -ge "$READ_THRESHOLD" ]; then
            nudge "p3: $cnt reads this session — dispatch a subagent for broad exploration?"
        fi
        ;;
    Edit|Write|NotebookEdit)
        # Check that last action_*.md line is a [PLAN] marker.
        action="$(latest_action_file "$CWD" || true)"
        if [ -n "$action" ]; then
            last_marker=$(grep -E '^\[(PLAN|BOOT_DONE|PREPARE_DONE|REFLECT_DONE|EXECUTE_EXIT|OBSERVE)\]' "$action" | tail -1 || true)
            if ! printf '%s' "$last_marker" | grep -q '^\[PLAN\]'; then
                nudge "p4: write [PLAN] in action_<sid>.md before file edits."
            fi
        fi
        ;;
    Bash)
        CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
        BG="$(printf '%s' "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null || true)"
        if printf '%s' "$CMD" | grep -qE 'sbatch|train|deepspeed|accelerate launch|torchrun|python.*train'; then
            if [ "$BG" != "true" ]; then
                nudge "p3: long job — set run_in_background=true + Monitor() every 10–15 min."
            fi
        fi
        ;;
    Agent)
        BG="$(printf '%s' "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null || true)"
        if [ "$BG" != "true" ]; then
            nudge "p3: Agent dispatch requires run_in_background=true (mandatory)."
        fi
        ;;
esac

# Default: allow silently (no output = pass).
exit 0
