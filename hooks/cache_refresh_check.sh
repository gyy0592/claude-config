#!/usr/bin/env bash
# cache_refresh_check.sh — v2.4 F3.
# UserPromptSubmit hook. Once cumulative input_tokens for this session exceeds a
# threshold (default 200000) since last refresh, emit a banner instructing the
# model to re-verify cache_hit_map AND re-grep ledgers for relevant prior lessons.
#
# Stdout banner is appended to the next user prompt (Claude Code UserPromptSubmit
# convention). All errors swallowed — must never block the prompt.
#
# State file: $PWD/.barry_workflow/<sid>/cache_refresh.json
#   {"last_total": <int>, "last_at": "<iso>"}
#
# Threshold: workflow_config.yaml cache_refresh.threshold_input_tokens (default 200000)

set -u  # not -e; we must never abort the prompt

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-__CLAUDE_CONFIG_DIR__}"
LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

# Read input JSON from Claude Code (session_id, cwd, transcript_path)
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
if [ -f "$CONFIG_DIR/content/rules/workflow_config.yaml" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$CONFIG_DIR/content/rules/workflow_config.yaml" "cache_refresh.threshold_input_tokens" 2>/dev/null || true)"
    [ -n "${v:-}" ] && THRESHOLD="$v"
fi

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
        # Count input + cache_read + cache_creation as "tokens fed into the model"
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
    cat <<BANNER
[CACHE_REFRESH_BANNER · +${DELTA} tokens since last check, threshold=${THRESHOLD}]
长会话累计 input_tokens 已超阈值。下一次工具调用前完成 2 项复核：

A. cache_hit_map 复核
  1. 重读 .barry_workflow/${SID}/state.md 的 cache_hit_map
  2. 对其中 hit: YES 的 artifact，≥3 轮未实际访问的降为 hit: NO 并本轮 Read 一次

B. ledger 合规自检（防止"记了不用"）
  1. grep workspace/bitter_lessons.md 当前 task: + 相关 tags:——是否在重复已知坑?
  2. grep workspace/rule_violations.md 当前 task: + tags:——是否已经犯过同款 AI 违规?
  3. grep ~/.claude/rules/{lessons,violation}.md tags:——跨项目级别相关条目?

完成后写一行 [CACHE_REFRESH_DONE 检查项 A+B] 到 action.md
BANNER
    python3 - "$STATE_FILE" "$CURRENT_TOTAL" <<'PY' 2>/dev/null || true
import json, sys, datetime
path, total = sys.argv[1], int(sys.argv[2])
json.dump({"last_total": total, "last_at": datetime.datetime.utcnow().isoformat()+"Z"}, open(path,"w"))
PY
fi

exit 0
