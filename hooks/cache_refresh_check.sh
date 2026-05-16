#!/usr/bin/env bash
# cache_refresh_check.sh — v2.5 (moved from UserPromptSubmit to PostToolUse).
#
# PostToolUse hook. After each tool call, sums input_tokens +
# cache_read_input_tokens + cache_creation_input_tokens across the session's
# transcript JSONL. If the delta since last refresh ≥ threshold, emits a
# banner instructing the model to:
#   A. re-verify cache_hit_map (long sessions evict YES rows from KV cache)
#   B. re-grep all 6 ledgers (global lessons/violation + 4 project ledgers)
#   C. self-audit autonomy / dispatch / recording compliance
#
# Why PostToolUse not UserPromptSubmit (v2.5 change): long autonomous tasks
# can run 50+ tool calls between user prompts. UserPromptSubmit fires 0 times
# during such a stretch, so the v2.4 implementation was silent exactly when
# the model is most at risk of drift.
#
# Banner is non-blocking (stderr → assistant context). Errors swallowed.
#
# State file: $PWD/.barry_workflow/<sid>/cache_refresh.json
#   {"last_total": <int>, "last_at": "<iso>"}
#
# Thresholds + ledger paths read from workflow_config.yaml — never hardcoded.

set -u  # not -e; never abort the tool call

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-__CLAUDE_CONFIG_DIR__}"
LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

SID="$(printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); print(d.get("session_id",""))
except Exception: pass' 2>/dev/null)"
CWD="$(printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); print(d.get("cwd",""))
except Exception: pass' 2>/dev/null)"
JSONL="$(printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); print(d.get("transcript_path",""))
except Exception: pass' 2>/dev/null)"

[ -z "$SID" ] || [ -z "$CWD" ] && exit 0

THRESHOLD=200000
YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$YAML" "cache_refresh.threshold_input_tokens" 2>/dev/null || true)"
    [ -n "${v:-}" ] && THRESHOLD="$v"
fi

read_path() {
    local key="$1" default="$2" v=""
    if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
        v="$(read_config "$YAML" "$key" 2>/dev/null || true)"
    fi
    printf '%s' "${v:-$default}"
}
P_GL="$(read_path "ledger_paths.global_lessons" "~/.claude/rules/lessons.md")"
P_GV="$(read_path "ledger_paths.global_violations" "~/.claude/rules/violation.md")"
P_BL="$(read_path "ledger_paths.project_bitter_lessons" "workspace/bitter_lessons.md")"
P_RV="$(read_path "ledger_paths.project_rule_violations" "workspace/rule_violations.md")"
P_SF="$(read_path "ledger_paths.project_successful_fixes" "workspace/successful_fixes.md")"
P_AL="$(read_path "ledger_paths.project_attempts_ledger" "workspace/attempts_ledger.md")"

SDIR="$CWD/.barry_workflow/$SID"
[ -d "$SDIR" ] || exit 0
STATE_FILE="$SDIR/cache_refresh.json"

CURRENT_TOTAL="$(python3 - "$JSONL" <<'PY' 2>/dev/null || echo 0
import sys, json, pathlib
p = pathlib.Path(sys.argv[1] or "")
if not p.exists():
    print(0); sys.exit(0)
total = 0
try:
    for line in p.read_text(errors="ignore").splitlines():
        if not line.strip(): continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        u = (obj.get("message") or {}).get("usage") or {}
        for k in ("input_tokens","cache_read_input_tokens","cache_creation_input_tokens"):
            total += int(u.get(k) or 0)
except Exception:
    pass
print(total)
PY
)"
CURRENT_TOTAL="${CURRENT_TOTAL:-0}"

LAST_TOTAL=0
if [ -f "$STATE_FILE" ]; then
    LAST_TOTAL="$(python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1])).get("last_total",0))
except Exception:
    print(0)' "$STATE_FILE" 2>/dev/null || echo 0)"
fi

DELTA=$((CURRENT_TOTAL - LAST_TOTAL))
if [ "$DELTA" -ge "$THRESHOLD" ]; then
    # v2.7 fix: PostToolUse stderr is debug-only — model never sees it.
    # Use hookSpecificOutput.additionalContext to actually surface this
    # banner. Previously these reminders never reached the AI.
    BODY="[CACHE_REFRESH_BANNER · +${DELTA} tokens since last check, threshold=${THRESHOLD}]
Long-session cumulative input_tokens exceeded the threshold. Before the next tool call complete 3 reviews:

A. cache_hit_map review
  1. Re-read .barry_workflow/${SID}/state.md cache_hit_map
  2. For artifacts marked hit: YES that haven't been actually accessed in ≥3 turns, downgrade to hit: NO and re-Read once this turn

B. 6-ledger compliance self-audit (don't 'record but never use' — grep each by current task: + relevant tags:)
  1. ${P_GL} — cross-project AI behavior wisdom (L-XXX)
  2. ${P_GV} — global AI violations (W-XXX)
  3. ${P_BL} — project technical pitfalls
  4. ${P_RV} — project AI violations
  5. ${P_SF} — project successful fixes
  6. ${P_AL} — project attempt log (ATT-N)

C. instruction compliance self-audit
  - autonomy: did you ask the user mid-task? Unless destructive / 3-failure-stop / explicit user opt-in, decide yourself.
  - dispatch: when touching >1 file / WebSearch / code change, did you use Agent(run_in_background=true)?
  - recording: did this turn have [PLAN] → tool → [OBSERVE], and a [BOARD_READ] header?

When done, write [CACHE_REFRESH_DONE A+B+C] to action.md"
    jq -n --arg m "$BODY" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $m
        }
    }'
    python3 - "$STATE_FILE" "$CURRENT_TOTAL" <<'PY' 2>/dev/null || true
import json, sys, datetime
path, total = sys.argv[1], int(sys.argv[2])
json.dump({"last_total": total, "last_at": datetime.datetime.utcnow().isoformat()+"Z"}, open(path,"w"))
PY
fi

exit 0
