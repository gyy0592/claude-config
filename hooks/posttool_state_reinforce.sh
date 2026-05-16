#!/usr/bin/env bash
# posttool_state_reinforce.sh — v2.5.
#
# PostToolUse hook (matcher=*). Every ~10k input_tokens (configurable in
# workflow_config.yaml state_reinforce.threshold_input_tokens), re-injects a
# ≤max_chars summary of the current router_<STATE>.md so long autonomous loops
# don't drift from the state's Allowed/Forbidden + autonomy rule.
#
# Token counting: same convention as cache_refresh_check.sh — sum of
# input_tokens + cache_read_input_tokens + cache_creation_input_tokens across
# the session's transcript JSONL.
#
# Non-blocking. Errors swallowed. exit 0 always.
#
# State file: $PWD/.barry_workflow/<sid>/state_reinforce.json
#   {"last_total": <int>, "last_state": "<STATUS>"}
# (last_state lets us force a re-inject if state just changed even if token
# delta below threshold — TODO future, currently we only check token delta.)

set -u

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

YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
THRESHOLD=10000
MAX_CHARS=400
if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$YAML" "state_reinforce.threshold_input_tokens" 2>/dev/null || true)"
    [ -n "${v:-}" ] && THRESHOLD="$v"
    v="$(read_config "$YAML" "state_reinforce.max_chars" 2>/dev/null || true)"
    [ -n "${v:-}" ] && MAX_CHARS="$v"
fi

SDIR="$CWD/.barry_workflow/$SID"
[ -d "$SDIR" ] || exit 0
SF_STATE="$SDIR/state.md"
SF_REINF="$SDIR/state_reinforce.json"
[ -f "$SF_STATE" ] || exit 0

STATUS="$(grep -m1 -E '^current_status:' "$SF_STATE" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
[ -z "$STATUS" ] && exit 0

ROUTER_FILE="$CONFIG_DIR/content/rules/router_${STATUS}.md"
[ -f "$ROUTER_FILE" ] || exit 0

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
LAST_STATE=""
if [ -f "$SF_REINF" ]; then
    LAST_TOTAL="$(python3 -c 'import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get("last_total",0))
except Exception: print(0)' "$SF_REINF" 2>/dev/null || echo 0)"
    LAST_STATE="$(python3 -c 'import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get("last_state",""))
except Exception: print("")' "$SF_REINF" 2>/dev/null || echo "")"
fi

DELTA=$((CURRENT_TOTAL - LAST_TOTAL))
STATE_CHANGED=0
[ "$LAST_STATE" != "$STATUS" ] && STATE_CHANGED=1

# Fire if token delta crossed threshold OR state changed since last fire.
if [ "$DELTA" -ge "$THRESHOLD" ] || [ "$STATE_CHANGED" = "1" ]; then
    # v2.5.3: no more MAX_CHARS truncation — re-inject the FULL router_<STATE>.md.
    # 6 routers are 1.2–2.4 KB; even the longest is < 600 tokens, smaller than
    # cache_refresh's banner. Truncation was discarding the always-on footer
    # (autonomy / dispatch / recording / lessons / facts_first) plus all
    # transition exit commands — exactly the parts AI most needed to remember.
    SUMMARY="$(python3 - "$ROUTER_FILE" <<'PY' 2>/dev/null
import sys, pathlib, re
text = pathlib.Path(sys.argv[1]).read_text(errors="ignore")
print(re.sub(r'\n{2,}', '\n', text).strip())
PY
)"
    # v2.7 fix: PostToolUse stderr does NOT reach the model. Use the JSON
    # envelope's hookSpecificOutput.additionalContext field instead, which
    # Claude Code wraps in a system-reminder and inserts next to the tool
    # result. Previously this banner went only to debug log.
    BANNER_BODY="[STATE_REINFORCE · state=${STATUS} · +${DELTA}/${THRESHOLD} tokens · full router]
${SUMMARY}"
    jq -n --arg m "$BANNER_BODY" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $m
        }
    }'
    python3 - "$SF_REINF" "$CURRENT_TOTAL" "$STATUS" <<'PY' 2>/dev/null || true
import json, sys, datetime
path, total, state = sys.argv[1], int(sys.argv[2]), sys.argv[3]
json.dump({
    "last_total": total,
    "last_state": state,
    "last_at": datetime.datetime.utcnow().isoformat()+"Z",
}, open(path,"w"))
PY
fi

exit 0
