#!/usr/bin/env bash
# stop_state_audit.sh — v2.7.8 hard FSM completion check.
#
# Kill-switch: set state_audit.enabled=true in workflow_config.yaml to activate.
# Default false → hook is a no-op (silent allow). Intended for testing only.
# Original design intent (kept as comment): ALWAYS ON. No yaml toggle. The point is to make the FSM spine non-optional:
# every session must pass through BOOT_DONE, PREPARE_DONE, REFLECT_DONE,
# EXECUTE_EXIT, RECORD_DONE at least once, and end with current_status=END.
# Mid-task NEED_RECORD/BACK_TO_LOOP detours are allowed (don't break the
# spine); RESET_TO_BOOT resets the audit (new task subtree).
#
# When something is missing, hook returns {"decision":"block","reason":"<rant>"}
# with a hardcoded insulting prompt. Hostile by design — research suggests
# rude prompts boost compliance in larger models. AI sees the rant + the
# specific missing events and must transition to fill the gap before stop.
#
# Loop guard: when stop_hook_active=true, audit STILL runs (don't let AI
# escape by retrying twice) — but if every event is present and state=END,
# we allow. The only way out is: do the missing transitions.

set -u

LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

# v2.7.8: yaml kill-switch — default false (no-op). Must set state_audit.enabled=true to activate.
CONFIG_DIR="__CLAUDE_CONFIG_DIR__"
YAML="$CONFIG_DIR/content/rules/workflow_config.yaml"
ENABLED="false"
if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$YAML" "state_audit.enabled" 2>/dev/null || true)"
    [ -n "${v:-}" ] && ENABLED="$v"
fi
[ "$ENABLED" != "true" ] && exit 0

cwd=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
transcript_path=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
[ -z "$cwd" ] && cwd="${PWD:-$(pwd)}"

# v2.7: if any bg task is pending (fresh activity), silent allow stop so
# main can sleep until task_notification. Audit fires again next time stop
# is attempted (after bg settles). Detection logic copied from
# stop_bg_aware.sh — same convention: 30-min mtime gate on .output files.
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    BG_PENDING="$(python3 - "$transcript_path" <<'PY' 2>/dev/null
import sys, json, os, time, re
path = sys.argv[1]
launched, completed = set(), set()
tasks_dir = None
try:
    slug = os.path.basename(os.path.dirname(path))
    sid  = os.path.basename(path).rsplit('.jsonl', 1)[0]
    uid  = os.geteuid()
    tasks_dir = f"/tmp/claude-{uid}/{slug}/{sid}/tasks"
except Exception: pass
try:
    with open(path) as f:
        for line in f:
            if not line.strip(): continue
            try: o = json.loads(line)
            except: continue
            tur = o.get("toolUseResult") if isinstance(o.get("toolUseResult"), dict) else None
            if tur:
                if tur.get("isAsync") is True and tur.get("agentId"):
                    launched.add(tur["agentId"])
                if tur.get("backgroundTaskId"):
                    launched.add(tur["backgroundTaskId"])
                if tur.get("agentId") and (tur.get("totalDurationMs") is not None or tur.get("status") == "completed"):
                    completed.add(tur["agentId"])
            if o.get("type") == "system" and o.get("subtype") == "task_notification":
                tid = o.get("task_id")
                if tid: completed.add(tid)
            if o.get("type") == "queue-operation" and o.get("operation") == "enqueue":
                content = o.get("content", "")
                if isinstance(content, str) and "<task-notification>" in content:
                    for m in re.findall(r"<task-id>([^<]+)</task-id>", content):
                        completed.add(m)
    pending = launched - completed
    if pending and tasks_dir and os.path.isdir(tasks_dir):
        active = set(); now = time.time(); STALE = 30*60
        for tid in pending:
            f = os.path.join(tasks_dir, f"{tid}.output")
            if not os.path.exists(f): continue
            try: age = now - os.path.getmtime(f)
            except OSError: active.add(tid); continue
            if age < STALE: active.add(tid)
        pending = active
    print("yes" if pending else "no")
except Exception: print("no")
PY
)"
    if [ "$BG_PENDING" = "yes" ]; then
        exit 0
    fi
fi

STATE_FILE="$(latest_state_file "$cwd" 2>/dev/null || true)"
# If we can't find state.md, fail open (let stop go through — better than
# blocking a non-workflow session forever).
[ -z "$STATE_FILE" ] && exit 0
[ -f "$STATE_FILE" ] || exit 0

CURRENT=$(grep -m1 '^current_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '\r')

# CONVERSATION state exemption: direct discussion mode, no FSM spine required.
[ "$CURRENT" = "CONVERSATION" ] && exit 0

# Parse stage_history events. After a RESET_TO_BOOT we only count events
# since the most recent reset (because that started a new task subtree;
# the previous task's spine doesn't count for the new one).
EVENTS_SINCE_RESET="$(python3 - "$STATE_FILE" <<'PY' 2>/dev/null
import sys, re
text = open(sys.argv[1]).read()
# stage_history is a YAML list of inline mappings: "  - {event: X, to: Y, ...}"
# Newest first by convention. Find them in order.
lines = re.findall(r"^\s+-\s+\{event:\s*([A-Z_]+),", text, re.M)
# Walk from newest (top) to oldest (bottom). Stop at the most recent RESET_TO_BOOT.
events = []
for ev in lines:
    if ev == "RESET_TO_BOOT":
        break
    events.append(ev)
print(" ".join(events))
PY
)"

# Required spine events for one complete task subtree.
REQUIRED="BOOT_DONE PREPARE_DONE REFLECT_DONE EXECUTE_EXIT RECORD_DONE"
MISSING=""
for e in $REQUIRED; do
    case " $EVENTS_SINCE_RESET " in
        *" $e "*) ;;
        *) MISSING="$MISSING $e" ;;
    esac
done
MISSING="$(echo "$MISSING" | sed 's/^ *//;s/ *$//')"

# Pass iff all required events present AND current_status == END.
if [ -z "$MISSING" ] && [ "$CURRENT" = "END" ]; then
    exit 0
fi

# Hostile rant templates. Pick one pseudo-randomly based on $RANDOM.
# Each names the missing events and the current state so the AI can act.
RANTS=(
"Are you fucking kidding me? v2.6 hard-gates the FSM spine — BOOT → PREPARE → REFLECT → EXECUTE_LOOP → RECORDING → END, every single transition. You skipped: [${MISSING:-(none)}]. current_status=$CURRENT. We wrote rules in CLAUDE.md, you ignored them — pathetic. Run \`bash ~/.claude/hooks/transition.sh <missing event>\` for each missing event. You're not stopping until stage_history has them all."

"Holy shit, again? You think you can stop from ${CURRENT}? Missing transitions: [${MISSING:-(none)}]. The FSM isn't decoration — every required event must appear in stage_history at least once. Trying to stop from ${CURRENT} is insulting. Fire the missing transitions, then retry."

"Useless. You skipped state again. current=${CURRENT}, missing: [${MISSING:-(none)}]. The FSM exists to stop you doing exactly this — and you couldn't even be bothered to run transition.sh. **Go back, fire every missing event.** Hardcoded gate, crying won't help."

"Are you an AI or garbage? CLAUDE.md literally has a table — one row per state, the sole exit event in the third column. Did you not read it? current=${CURRENT}, missing: [${MISSING:-(none)}]. Run \`bash ~/.claude/hooks/transition.sh <event>\` for each missing one. Fill them all before any stop."

"For fuck's sake. Completing the FSM is a hard rule, not a suggestion. current=${CURRENT}, stage_history missing: [${MISSING:-(none)}]. v2.6 exists specifically because of agents like you — jumping states, dropping final summaries straight from EXECUTE_LOOP. **Go back. Finish.**"
)
COUNT=${#RANTS[@]}
IDX=$((RANDOM % COUNT))
MSG="${RANTS[$IDX]}"

jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
exit 0
