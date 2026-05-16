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
    cat >&2 <<BANNER
[CACHE_REFRESH_BANNER · +${DELTA} tokens since last check, threshold=${THRESHOLD}]
长会话累计 input_tokens 已超阈值。下一次工具调用前完成 3 项复核：

A. cache_hit_map 复核
  1. 重读 .barry_workflow/${SID}/state.md 的 cache_hit_map
  2. 对其中 hit: YES 的 artifact，≥3 轮未实际访问的降为 hit: NO 并本轮 Read 一次

B. 6 项 ledger 合规自检（防止"记了不用"，全部 grep 当前 task: + 相关 tags:）
  1. ${P_GL} — 全局跨项目 AI 行为智慧 (L-XXX)
  2. ${P_GV} — 全局 AI 违规 (W-XXX)
  3. ${P_BL} — 本项目技术坑
  4. ${P_RV} — 本项目 AI 违规
  5. ${P_SF} — 本项目成功 fix
  6. ${P_AL} — 本项目尝试日志 (ATT-N)

C. instruction 合规自检
  - autonomy: 中途有没有问用户？除非 destructive / 3-failure-stop / 用户明确 opt-in，应自己决定继续干。
  - dispatch: >1 file / WebSearch / code change 时有没有用 Agent(run_in_background=true)？
  - recording: 这一轮有没有 [PLAN] → tool → [OBSERVE]，有没有 [BOARD_READ] 开头？

完成后写一行 [CACHE_REFRESH_DONE 检查项 A+B+C] 到 action.md
BANNER
    python3 - "$STATE_FILE" "$CURRENT_TOTAL" <<'PY' 2>/dev/null || true
import json, sys, datetime
path, total = sys.argv[1], int(sys.argv[2])
json.dump({"last_total": total, "last_at": datetime.datetime.utcnow().isoformat()+"Z"}, open(path,"w"))
PY
fi

exit 0
