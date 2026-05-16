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

# v2.5.5: master kill-switch. yaml stop_gate.enabled defaults to false; users
# opt in by setting it true in workflow_config.yaml. When false, this hook is
# a no-op (silent allow), matching the pre-v2.5.4 behaviour for everyone who
# hasn't explicitly turned it on.
ENABLED="false"
YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$YAML" "stop_gate.enabled" 2>/dev/null || true)"
    [ -n "${v:-}" ] && ENABLED="$v"
fi
[ "$ENABLED" != "true" ] && exit 0

# Resolve stale-minutes threshold from yaml (default 30).
STALE_MIN=30
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
    STOP_VAL=$(jq -r '.stop // -1' "$DECISION_FILE" 2>/dev/null)
    REFLECT_ROUNDS=$(jq -r '.reflect_rounds // 0' "$DECISION_FILE" 2>/dev/null)
    REASON=$(jq -r '.reason // ""' "$DECISION_FILE" 2>/dev/null)

    # Require reflect_rounds >= 5 for a valid stop=1 verdict.
    if [ "$STOP_VAL" = "1" ] && [ "${REFLECT_ROUNDS:-0}" -lt 5 ] 2>/dev/null; then
        STOP_VAL="-1"
    fi

    case "$STOP_VAL" in
        1)
            rm -f "$DECISION_FILE"
            exit 0
            ;;
        0)
            rm -f "$DECISION_FILE"
            MSG="[stop_gate] Self-reflect verdict: NOT done — reason: ${REASON}. Continue working."
            jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
            exit 0
            ;;
        *)
            # -1 or invalid — placeholder still pending. Re-emit instructions.
            ;;
    esac
fi

# No usable decision yet → create placeholder + block + ask main to self-reflect.
mkdir -p "$SDIR" 2>/dev/null || true
if [ ! -f "$DECISION_FILE" ]; then
    cat > "$DECISION_FILE" <<'JSON'
{
  "stop": -1,
  "reflect_rounds": 0,
  "all_constraints_met": "no",
  "all_goals_met": "no",
  "reason": "AWAITING_SELF_REFLECT — main must fill all fields before retrying stop"
}
JSON
fi

GOAL_PATH="${cwd}/workspace/$(basename "${cwd}")/goal.md"
# Try common task dir patterns
GOAL_HINT=""
if [ -d "${cwd}/workspace" ]; then
    FOUND_GOAL=$(find "${cwd}/workspace" -name "goal.md" -maxdepth 3 2>/dev/null | head -1)
    [ -n "$FOUND_GOAL" ] && GOAL_HINT="goal.md found at: ${FOUND_GOAL} — READ IT before reflecting."
fi
[ -z "$GOAL_HINT" ] && GOAL_HINT="No goal.md found — reconstruct goal from session context."

MSG="[stop_gate] bg settled. Before stopping, YOU must self-reflect and fill ${DECISION_FILE}.

MANDATORY steps (do all, then retry stop):
1. ${GOAL_HINT}
2. Run 5 rebuttal rounds (spawn Agent(run_in_background=true) once per round, read reply, repeat).
   Each round: ask 'did we fully achieve the goal? any constraint violated?'
3. After round 5 consensus, Edit ${DECISION_FILE} with ALL fields:
   (a) \"stop\": 1 (all goals met + no violations) OR 0 (incomplete)
   (b) \"reflect_rounds\": 5  (must be exactly 5 — hook rejects < 5)
   (c) \"all_constraints_met\": \"yes\" or \"no\"
   (d) \"all_goals_met\": \"yes\" or \"no\"
   (e) \"reason\": one-sentence summary
4. Retry stop. Hook will consume the file and allow if stop=1 and reflect_rounds=5."

jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
exit 0
