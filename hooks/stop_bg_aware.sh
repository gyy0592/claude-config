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
    REASON=$(jq -r '.reason // ""' "$DECISION_FILE" 2>/dev/null)

    # v2.5.5: tri-state. -1 = haiku hasn't filled it in yet (placeholder this
    # hook created on the previous fire). 0/1 = haiku's verdict. We only
    # consume on 0/1, not on -1, so the prompt re-fires until haiku acts.
    case "$STOP_VAL" in
        1)
            rm -f "$DECISION_FILE"
            exit 0
            ;;
        0)
            rm -f "$DECISION_FILE"
            MSG="[stop_bg_aware] Haiku judge says NOT yet done — reason: ${REASON}. Continue working; another stop attempt will re-run the judge."
            jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
            exit 0
            ;;
        *)
            # -1 (or any other unexpected value) — placeholder still there,
            # haiku hasn't edited it. Re-emit the prompt; do NOT delete.
            ;;
    esac
fi

# No usable decision yet → ensure placeholder exists with schema haiku can Edit,
# then block + ask main to dispatch a haiku judge subagent.
# v2.5.5: hook now creates the placeholder so haiku only needs to Edit two
# fields (stop, reason), not Write a full new JSON. Reduces error surface.
mkdir -p "$SDIR" 2>/dev/null || true
if [ ! -f "$DECISION_FILE" ]; then
    cat > "$DECISION_FILE" <<'JSON'
{
  "stop": -1,
  "reason": "AWAITING_HAIKU_JUDGE — replace -1 with 0 or 1, replace this string with one-sentence reason"
}
JSON
fi
# v2.5.5: JUDGE_PROMPT must be FIRST-PERSON imperative addressed to the
# subagent itself. Earlier versions said "dispatch a haiku judge subagent..."
# which caused the receiving subagent to misread its own role as dispatcher,
# spawn a sub-sub-agent, then sit waiting for the file it was supposed to
# write itself (observed killed task a22d3142a4d0e0f7e). New phrasing: "YOU
# are the judge. DO NOT spawn another subagent. YOU run the bash, YOU answer,
# YOU Write the file, YOU exit."
JUDGE_PROMPT="MANDATORY: your VERY FIRST tool call MUST be Edit on ${DECISION_FILE}. Do NOT spawn subagents. Do NOT just write your verdict in chat — the gate ONLY reads the file, chat is ignored.

Workflow (do all 3, in order, then exit):
1. Bash: python3 ${CONFIG_DIR}/scripts/extract_transcript.py ${transcript_path} --tool-result-lines 3 | tail -600
2. Decide: stop=1 if (user's last request done) AND (FSM walked: BOOT→PREPARE→REFLECT→EXECUTE_LOOP→RECORDING→END events present) AND (no autonomy violation). Otherwise stop=0.
3. Two Edit calls on ${DECISION_FILE}:
   (a) old_string=\`\"stop\": -1\`  new_string=\`\"stop\": 1\`  (or 0)
   (b) old_string=\`AWAITING_HAIKU_JUDGE — replace -1 with 0 or 1, replace this string with one-sentence reason\`  new_string=\`<your one-sentence reason, ≤180 chars>\`

If you skip step 3 the user is stuck in an infinite stop loop. Edit the file, then exit silently."

MSG="[stop_bg] bg idle ≥${STALE_MIN}min. Dispatch judge (paste below as-is, then retry stop):

Agent(model=\"haiku\", subagent_type=\"general-purpose\", run_in_background=true, prompt=\"\"\"${JUDGE_PROMPT}\"\"\")"

jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
exit 0
