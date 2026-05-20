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

CONFIG_DIR="__CLAUDE_CONFIG_DIR__"
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
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"

# If the model is about to call Agent / Task / SendMessage right now, no nag.
case "$TOOL" in
    Agent|SendMessage|Task) exit 0 ;;
esac

STATE_FILE="$(latest_state_file "$CWD" 2>/dev/null || true)"
[ -z "$STATE_FILE" ] && exit 0
[ -f "$STATE_FILE" ] || exit 0

STATUS="$(grep -m1 -E '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
[ "$STATUS" = "REFLECT" ] || exit 0

# v2.5.1 (F2 fix per user L114): the previous "any reflection_*.md exists" proxy
# was a false-positive minefield (empty placeholder files, leftover INFERENCE_GATE
# files, stale rounds from prior tasks all muted the nag). Correct test: read the
# transcript JSONL directly and count tool_use events whose name is Agent / Task /
# SendMessage. Suppress nag iff ≥1 such event was issued THIS turn or earlier in
# the same session. Direct evidence, no proxy.
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    if python3 - "$TRANSCRIPT" <<'PY' 2>/dev/null
import sys, json, pathlib
p = pathlib.Path(sys.argv[1])
try:
    for line in p.read_text(errors='ignore').splitlines():
        if not line.strip(): continue
        try: obj = json.loads(line)
        except Exception: continue
        msg = obj.get("message") or {}
        content = msg.get("content") or []
        if not isinstance(content, list): continue
        for c in content:
            if not isinstance(c, dict): continue
            if c.get("type") == "tool_use" and c.get("name") in ("Agent", "Task", "SendMessage"):
                sys.exit(0)  # found one -> hook will skip the nag
except Exception:
    pass
sys.exit(1)  # nothing found -> hook will emit the nag
PY
    then
        exit 0
    fi
fi

MSG="REFLECT state: no rebuttal subagent spawned yet this session (checked transcript tool_use events). Next action MUST be Agent(run_in_background=true, subagent_type=general-purpose, ...) — see ~/.claude/rules/states/reflect.md."
# Truncate to MAX_CHARS.
if [ "${#MSG}" -gt "$MAX_CHARS" ]; then
    MSG="${MSG:0:$((MAX_CHARS-3))}..."
fi

# v2.7 fix: additionalContext (visible to model on allow), not
# permissionDecisionReason (silent on allow).
jq -n --arg m "$MSG" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        additionalContext: $m
    }
}'
exit 0
