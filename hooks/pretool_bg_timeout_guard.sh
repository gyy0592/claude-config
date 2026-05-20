#!/usr/bin/env bash
# pretool_bg_timeout_guard.sh — v2.7.22.
#
# PreToolUse hook. When tool_input.run_in_background == true on a Bash call,
# enforce that the command has a bounded lifetime AND does not loop forever.
#
# Motivation: bg tasks that loop forever block stop_gate forever AND burn
# tokens via task_notification storms. Acceptable bg patterns:
#   - timeout N <cmd>                          (hard cap)
#   - sleep N && <one-shot check>              (sleep-then-exit)
#   - bounded for loop: `for i in {1..N}; do ... done` with N <= 10
#
# DENIED patterns:
#   - while true / while :                     (infinite)
#   - tail -f                                  (never exits)
#   - for ... seq 1 999999 ...                 (unbounded numeric)
#   - bare long-running cmd with no timeout/sleep wrapper
#   - bounded loops with N > 10 (use timeout instead)
#
# Agent tool with run_in_background is NOT guarded here — subagents follow
# single-round-exit protocol on their own.

set -u

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
RUN_BG=$(printf '%s' "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Only Bash + run_in_background=true is guarded.
[ "$TOOL_NAME" != "Bash" ] && exit 0
case "$RUN_BG" in
    true|True|TRUE|1) ;;
    *) exit 0 ;;
esac
[ -z "$CMD" ] && exit 0

deny() {
    local reason="$1"
    jq -n --arg r "$reason" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

# --- DENY: explicit infinite-loop / tail-follow patterns ---
if echo "$CMD" | grep -qE '\bwhile[[:space:]]+(true|:)\b'; then
    deny "[bg-guard] denied: 'while true' / 'while :' infinite loops block stop_gate forever. Use 'timeout N cmd' or 'sleep N && check_once'."
fi
if echo "$CMD" | grep -qE '\btail[[:space:]]+-[^[:space:]]*f'; then
    deny "[bg-guard] denied: 'tail -f' never exits. Use 'timeout 300 tail -f ...' or 'tail -n 50 ...' for one-shot."
fi
if echo "$CMD" | grep -qE '\bseq[[:space:]]+[0-9]+[[:space:]]+[0-9]{4,}'; then
    deny "[bg-guard] denied: seq with >=4-digit upper is effectively unbounded. Cap loop count or use 'timeout'."
fi

# --- POSITIVE: any of these forms passes ---
# 1. starts with `timeout N ...` (optional `bash -c`/`sh -c` wrapper)
if echo "$CMD" | grep -qE '(^|[;&|]|^bash[[:space:]]+-c[[:space:]]+["'\''"]?|^sh[[:space:]]+-c[[:space:]]+["'\''"]?)[[:space:]]*timeout[[:space:]]+[0-9]+'; then
    exit 0
fi
# 2. `sleep N && ...` or `sleep N; ...` (one-shot delayed action)
if echo "$CMD" | grep -qE '^[[:space:]]*sleep[[:space:]]+[0-9]+[[:space:]]*(&&|;|$)'; then
    exit 0
fi
# 3. bounded for-loop {1..N} with N<=10
if echo "$CMD" | grep -qE '\bfor[[:space:]]+[a-zA-Z_]+[[:space:]]+in[[:space:]]+\{1\.\.([0-9]+)\}'; then
    N=$(echo "$CMD" | sed -nE 's/.*\bfor[[:space:]]+[a-zA-Z_]+[[:space:]]+in[[:space:]]+\{1\.\.([0-9]+)\}.*/\1/p' | head -1)
    if [ -n "$N" ] && [ "$N" -le 10 ]; then
        exit 0
    else
        deny "[bg-guard] denied: bounded for loop {1..$N} exceeds N=10. Use 'timeout' for hard cap, or smaller bound."
    fi
fi
# 4. plain `sleep N` alone (heartbeat-style one-shot pause)
if echo "$CMD" | grep -qE '^[[:space:]]*sleep[[:space:]]+[0-9]+[[:space:]]*$'; then
    exit 0
fi

# --- Fallthrough: no bound detected ---
deny "[bg-guard] denied: bg Bash needs a bounded lifetime. Prepend 'timeout N' or use 'sleep N && cmd' / 'for i in {1..N≤10}; do ...; done'. Current cmd has no detected upper bound. Monitoring pattern: 'sleep 300 && check_once && exit' — wakes main via task_notification, no token storm."
