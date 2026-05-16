#!/usr/bin/env bash
# stop_bg_aware.sh — v2.5.4 Stop hook with haiku-judge gate.
#
# Trigger logic (any of these → bg "settled" → consult judge gate):
#   - No bg task launched/pending at all.
#   - Some bg task pending BUT its /tmp/.../tasks/<id>.output mtime is older
#     than yaml `stop_gate.bg_stale_minutes` (default 30 min).
#
# Once bg is settled, gate logic:
#   .barry_workflow/<sid>/stop_decision.json  schema: {"stop": 0|1, "reason": "..."}
#
#   - File absent  → block + reason teaches main to spawn a haiku subagent
#     that runs scripts/extract_transcript.py + judges + writes the file.
#   - {"stop": 1} → consume (delete) file + silent allow stop.
#   - {"stop": 0} → consume + block + reason includes the haiku's reason.
#
# stop_hook_active=true short-circuits → silent allow, preventing infinite loops.
# Errors swallowed; if anything is malformed, fall-open (allow stop).

set -u

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-__CLAUDE_CONFIG_DIR__}"
LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

input="$(cat 2>/dev/null || true)"
[ -z "$input" ] && exit 0

stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null)
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""' 2>/dev/null)
cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$cwd" ] && cwd="${PWD:-$(pwd)}"

# Loop guard: if hook fired and AI is re-attempting stop, accept.
if [ "$stop_hook_active" = "true" ]; then
    exit 0
fi

# Resolve stale-minutes threshold from yaml (default 30).
STALE_MIN=30
YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$YAML" "stop_gate.bg_stale_minutes" 2>/dev/null || true)"
    [ -n "${v:-}" ] && STALE_MIN="$v"
fi

# Parse transcript: count launched bg ids minus completed ids, then apply
# mtime gate. STALE_MIN minutes of silence → drop from "pending" set.
bg_state="none"
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    bg_state=$(STALE_MIN="$STALE_MIN" python3 - "$transcript_path" 2>/dev/null << 'PY'
import sys, json, os, time, re
path = sys.argv[1]
stale_sec = int(os.environ.get("STALE_MIN", "30")) * 60

launched_ids = set()
completed_ids = set()
tasks_dir = None
try:
    slug = os.path.basename(os.path.dirname(path))
    sid = os.path.basename(path).rsplit('.jsonl', 1)[0]
    uid = os.geteuid()
    tasks_dir = f"/tmp/claude-{uid}/{slug}/{sid}/tasks"
except Exception:
    pass

try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try: obj = json.loads(line)
            except: continue
            tur = obj.get('toolUseResult') if isinstance(obj.get('toolUseResult'), dict) else None
            if tur:
                if tur.get('isAsync') is True and tur.get('agentId'):
                    launched_ids.add(tur['agentId'])
                if tur.get('backgroundTaskId'):
                    launched_ids.add(tur['backgroundTaskId'])
                if tur.get('agentId') and (
                    tur.get('totalDurationMs') is not None
                    or tur.get('status') == 'completed'
                ):
                    completed_ids.add(tur['agentId'])
            if obj.get('type') == 'system' and obj.get('subtype') == 'task_notification':
                tid = obj.get('task_id')
                if tid: completed_ids.add(tid)
            if obj.get('type') == 'queue-operation' and obj.get('operation') == 'enqueue':
                content = obj.get('content', '')
                if isinstance(content, str) and '<task-notification>' in content:
                    for m in re.findall(r'<task-id>([^<]+)</task-id>', content):
                        completed_ids.add(m)

    pending = launched_ids - completed_ids
    if pending and tasks_dir and os.path.isdir(tasks_dir):
        active = set()
        now = time.time()
        for tid in pending:
            ofile = os.path.join(tasks_dir, f"{tid}.output")
            if not os.path.exists(ofile):
                continue
            try:
                age = now - os.path.getmtime(ofile)
            except OSError:
                active.add(tid); continue
            if age < stale_sec:
                active.add(tid)
        pending = active

    print('pending' if pending else 'none')
except Exception:
    print('unknown')
PY
)
fi

# bg truly pending (fresh activity) → silent allow stop; main sleeps until notif.
if [ "$bg_state" = "pending" ]; then
    exit 0
fi

# bg settled: consult the haiku-judged decision file.
SDIR="${cwd}/.barry_workflow/${session_id}"
DECISION_FILE="${SDIR}/stop_decision.json"

if [ -f "$DECISION_FILE" ]; then
    STOP_VAL=$(jq -r '.stop // 0' "$DECISION_FILE" 2>/dev/null)
    REASON=$(jq -r '.reason // ""' "$DECISION_FILE" 2>/dev/null)
    # Consume the file regardless of value (one-shot decision).
    rm -f "$DECISION_FILE"
    if [ "$STOP_VAL" = "1" ]; then
        exit 0
    else
        MSG="[stop_bg_aware] Haiku judge says NOT yet done — reason: ${REASON}. Continue working; another stop attempt will re-run the judge."
        jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
        exit 0
    fi
fi

# No decision file yet → block + ask main to dispatch a haiku judge subagent.
# The reason is the prompt: it tells main exactly what to do (one Agent call,
# fixed prompt template) so this can't ambiguously expand into more work.
JUDGE_PROMPT="读取 ${transcript_path} 的最后 200 行（可用：\`python3 ${CONFIG_DIR}/scripts/extract_transcript.py ${transcript_path} --tool-result-lines 3 | tail -800\`），判断本会话是否真正完成可以停止。判定 3 个问题：(1) 任务完成了吗？(2) 所有需要记录的东西（ledger/action.md）记录了吗？(3) 是否遵守自主执行规则（不问用户、不在错的 state 干活、不跳过 transition）？三问都 yes 写 stop=1，任何一项 no 写 stop=0。把结论写到 ${SDIR}/stop_decision.json，schema: {\"stop\": 0|1, \"reason\": \"<one-sentence>\"}。写完立刻 exit。"

MSG="[stop_bg_aware] bg settled (no fresh activity ≥ ${STALE_MIN} min). Before stop, dispatch a haiku judge subagent: Agent(model=\"haiku\", run_in_background=true, subagent_type=\"general-purpose\", prompt=<see below>). After it writes stop_decision.json, re-attempt stop and this hook will honour the verdict.

Judge prompt: ${JUDGE_PROMPT}"

jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
exit 0
