#!/usr/bin/env bash
# transition.sh — FSM state mutator. Called by main as:
#   bash transition.sh <event>  [--reason=<...>]
# Events:
#   BOOT_DONE | PREPARE_DONE | REFLECT_DONE | EXECUTE_EXIT
#   NEED_RECORD | RECORD_DONE | BACK_TO_LOOP
#   RESET_TO_BOOT
#
# RECORDING state (v2.4): a dedicated ledger-writing state. EXECUTE_EXIT now
# routes EXECUTE_LOOP → RECORDING (was → REFLECT); from REFLECT or
# EXECUTE_LOOP, NEED_RECORD can also enter RECORDING mid-task. RECORDING exits
# via either RECORD_DONE → END (final) or BACK_TO_LOOP → prev state (resume).
#
# RESET_TO_BOOT: same-session task switch. Use when user changes the active task
# (goal.md updated, new request unrelated to current FSM track). Re-enters BOOT
# so the AI re-reads the updated goal.md + ledger and re-walks the pipeline.
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

EVENT="${1:-}"
REASON=""
shift || true
SID_ARG=""
for arg in "$@"; do
    case "$arg" in
        --reason=*) REASON="${arg#--reason=}" ;;
        --sid=*)    SID_ARG="${arg#--sid=}" ;;
    esac
done

# v2.5.2 (F6 fix): err_both() now lives in _session_lib.sh (already sourced above)
# so every AI-invoked script can use it. See lib for rationale.

# v2.5.2 (F6 fix — did-you-mean for state-name vs event-name confusion).
# The valid events end in _DONE / _EXIT / _RECORD / etc; AI frequently passes
# the bare state name (e.g. "PREPARE" instead of "PREPARE_DONE"). This maps
# every state name → the canonical event that leaves that state, so the error
# message names the exact event the caller almost certainly intended.
event_for_state() {
    case "$1" in
        BOOT)         echo "BOOT_DONE" ;;
        PREPARE)      echo "PREPARE_DONE" ;;
        REFLECT)      echo "REFLECT_DONE" ;;
        EXECUTE_LOOP|EXECUTE) echo "EXECUTE_EXIT" ;;
        RECORDING)    echo "RECORD_DONE   (or BACK_TO_LOOP / NEED_RECORD depending on intent)" ;;
        END)          echo "(none — END is terminal; use RESET_TO_BOOT for a new task)" ;;
        *)            echo "" ;;
    esac
}

VALID_EVENTS="BOOT_DONE|PREPARE_DONE|REFLECT_DONE|EXECUTE_EXIT|NEED_RECORD|RECORD_DONE|BACK_TO_LOOP|RESET_TO_BOOT"

if [ -z "$EVENT" ]; then
    err_both "usage: transition.sh <${VALID_EVENTS}> [--sid=<session-id>] [--reason=...]"
    exit 2
fi

CWD="${PWD}"
# v2.5.1 (F4 fix): SID resolution order:
#   1. --sid=<X> CLI arg (explicit)
#   2. $PWD/.barry_workflow/CURRENT_SID file (written by session_boot.sh)
#   3. mtime-newest <sid>/state.md (legacy fallback — self-reinforcing wrong-pick bug, kept only for first-run / pre-v2.5.1 sessions)
if [ -n "$SID_ARG" ] && [ -f "$CWD/.barry_workflow/$SID_ARG/state.md" ]; then
    STATE_FILE="$CWD/.barry_workflow/$SID_ARG/state.md"
else
    STATE_FILE="$(latest_state_file "$CWD" || true)"
fi
if [ -z "$STATE_FILE" ]; then
    echo "transition.sh: no state file under $(barry_root "$CWD")" >&2
    exit 1
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Capture OLD status BEFORE the Python mutator rewrites state.md
OLD_STATUS="$(grep '^current_status:' "$STATE_FILE" | awk '{print $2}' | tr -d '[:space:]')"
# Back-compat: state.md created before v2.4 lacks prev_status. `|| true` keeps
# set -e from killing the script; missing line yields empty → "null" below.
OLD_PREV_STATUS="$(grep '^prev_status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]' || true)"
[ -z "$OLD_PREV_STATUS" ] && OLD_PREV_STATUS="null"

# v2.5.5 (REFLECT round-count guard): when AI tries to exit REFLECT, count the
# Agent / Task / SendMessage tool_use events recorded in the session transcript.
# If they don't meet the minimum implied by yaml `reflect.rounds_default` (= at
# least 1 Agent/Task spawn AND at least rounds-1 SendMessages), block the exit.
# Rationale: failures observed in remote sessions e25384d9 and d5413e83 had AI
# pass straight through REFLECT_DONE without ever spawning a rebuttal subagent.
# yaml `reflect.enforce_min_rounds: true` toggles this; default off so it
# doesn't break sessions migrating in.
if [ "$EVENT" = "REFLECT_DONE" ]; then
    YAML="__CLAUDE_CONFIG_DIR__/content/rules/workflow_config.yaml"
    ENFORCE="false"
    REQ_ROUNDS=2
    if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
        v="$(read_config "$YAML" reflect.enforce_min_rounds 2>/dev/null || true)"
        [ -n "${v:-}" ] && ENFORCE="$v"
        v="$(read_config "$YAML" reflect.rounds_default 2>/dev/null || true)"
        [ -n "${v:-}" ] && REQ_ROUNDS="$v"
    fi
    if [ "$ENFORCE" = "true" ] && [ "$OLD_STATUS" = "REFLECT" ]; then
        # Discover the transcript path from session_id + cwd encoding.
        SID_FOR_TRANSCRIPT="$(basename "$(dirname "$STATE_FILE")")"
        ENCODED_CWD="$(echo "$CWD" | sed 's|/|-|g')"
        TRANSCRIPT="$HOME/.claude/projects/${ENCODED_CWD}/${SID_FOR_TRANSCRIPT}.jsonl"
        if [ -f "$TRANSCRIPT" ]; then
            COUNTS="$(REQ="$REQ_ROUNDS" python3 - "$TRANSCRIPT" <<'PY' 2>/dev/null
import sys, json
agent=task=sendmsg=0
try:
    with open(sys.argv[1]) as f:
        for line in f:
            if not line.strip(): continue
            try: d=json.loads(line)
            except: continue
            for c in (d.get("message") or {}).get("content") or []:
                if not isinstance(c, dict): continue
                if c.get("type") == "tool_use":
                    n = c.get("name","")
                    if n == "Agent": agent += 1
                    elif n == "Task": task += 1
                    elif n == "SendMessage": sendmsg += 1
except Exception: pass
print(f"{agent} {task} {sendmsg}")
PY
)"
            read -r AGENT_N TASK_N SENDMSG_N <<<"$COUNTS"
            SPAWN_TOTAL=$((AGENT_N + TASK_N))
            REQUIRED_SENDMSG=$((REQ_ROUNDS - 1))
            if [ "$SPAWN_TOTAL" -lt 1 ] || [ "$SENDMSG_N" -lt "$REQUIRED_SENDMSG" ]; then
                err_both "transition.sh: REFLECT_DONE blocked. Round budget = ${REQ_ROUNDS}; need ≥1 Agent/Task spawn AND ≥${REQUIRED_SENDMSG} SendMessage. This session has: Agent=${AGENT_N}, Task=${TASK_N}, SendMessage=${SENDMSG_N}. Spawn the rebuttal subagent (Agent(run_in_background=true,...)) and complete the rounds, then retry. To bypass set reflect.enforce_min_rounds=false in workflow_config.yaml."
                exit 2
            fi
        fi
    fi
fi

# Map event → new status. NEW_PREV is the prev_status to write back; null means clear.
NEW_PREV="null"
case "$EVENT" in
    BOOT_DONE)     NEW=PREPARE ;;
    PREPARE_DONE)  NEW=REFLECT ;;
    REFLECT_DONE)  NEW=EXECUTE_LOOP ;;
    EXECUTE_EXIT)
        # v2.4: EXECUTE_LOOP exits now always go through RECORDING (was REFLECT).
        NEW=RECORDING
        NEW_PREV="$OLD_STATUS"
        ;;
    NEED_RECORD)
        # Mid-task detour into RECORDING from REFLECT or EXECUTE_LOOP.
        if [ "$OLD_STATUS" != "REFLECT" ] && [ "$OLD_STATUS" != "EXECUTE_LOOP" ]; then
            err_both "transition.sh: NEED_RECORD only valid from REFLECT or EXECUTE_LOOP (current: $OLD_STATUS)"
            exit 2
        fi
        NEW=RECORDING
        NEW_PREV="$OLD_STATUS"
        ;;
    RECORD_DONE)
        if [ "$OLD_STATUS" != "RECORDING" ]; then
            err_both "transition.sh: RECORD_DONE only valid from RECORDING (current: $OLD_STATUS)"
            exit 2
        fi
        NEW=END
        ;;
    BACK_TO_LOOP)
        if [ "$OLD_STATUS" != "RECORDING" ]; then
            err_both "transition.sh: BACK_TO_LOOP only valid from RECORDING (current: $OLD_STATUS)"
            exit 2
        fi
        if [ "$OLD_PREV_STATUS" = "null" ] || [ -z "$OLD_PREV_STATUS" ]; then
            echo "transition.sh: BACK_TO_LOOP found no prev_status — falling back to EXECUTE_LOOP" >&2
            NEW=EXECUTE_LOOP
        else
            NEW="$OLD_PREV_STATUS"
        fi
        ;;
    RESET_TO_BOOT) NEW=BOOT ;;
    *)
        # v2.5.2 (F6 fix): output to BOTH stdout and stderr (survives 2>/dev/null)
        # and include a did-you-mean hint if the caller passed a state name instead
        # of an event name (the dominant failure mode observed in transcripts).
        SUGGEST="$(event_for_state "$EVENT")"
        if [ -n "$SUGGEST" ]; then
            err_both "transition.sh: '$EVENT' is a STATE name, not an EVENT name. Did you mean: $SUGGEST"
        else
            err_both "transition.sh: unknown event '$EVENT'. Valid events: $VALID_EVENTS"
        fi
        exit 2
        ;;
esac

# Derive session dir and SID from state file path (layout: .barry_workflow/<sid>/state.md)
SDIR="$(dirname "$STATE_FILE")"
SID="$(basename "$SDIR")"

python3 - "$STATE_FILE" "$NEW" "$EVENT" "$REASON" "$TS" "$NEW_PREV" <<'PY'
import sys, re, pathlib
path, new_status, event, reason, ts, new_prev = sys.argv[1:]
src = pathlib.Path(path).read_text()
m = re.search(r"```yaml\n---YAML---\n(.*?)\n---YAML---\n```", src, re.S)
if not m:
    print(f"transition.sh: YAML block not found in {path}", file=sys.stderr)
    sys.exit(1)
yaml_body = m.group(1)
# Naive line-based rewrite to avoid yaml dep.
out_lines = []
saw_prev = False
for line in yaml_body.splitlines():
    if line.startswith("current_status:"):
        out_lines.append(f"current_status: {new_status}")
    elif line.startswith("prev_status:"):
        out_lines.append(f"prev_status: {new_prev}")
        saw_prev = True
    elif line.startswith("last_transition:"):
        out_lines.append(f"last_transition: {{event: {event}, at: {ts}, reason: \"{reason}\"}}")
    elif line.startswith("stage_history:"):
        # Normalise stage_history: [] → empty list, then append new item.
        out_lines.append("stage_history:")
        # Drop pre-existing inline-empty marker if present.
        out_lines.append(f"  - {{event: {event}, to: {new_status}, at: {ts}, reason: \"{reason}\"}}")
    else:
        out_lines.append(line)
# Back-compat: if state.md was created before prev_status existed, inject it after current_status.
if not saw_prev:
    patched = []
    for line in out_lines:
        patched.append(line)
        if line.startswith("current_status:"):
            patched.append(f"prev_status: {new_prev}")
    out_lines = patched
new_yaml = "\n".join(out_lines)
new_src = src[:m.start(1)] + new_yaml + src[m.end(1):]
pathlib.Path(path).write_text(new_src)
print(f"{event} → {new_status}")
PY

# v2.5.1 (F4 belt-and-braces): reset state.md mtime to 1970 so that any legacy
# code path still calling mtime-newest selection doesn't latch onto the file we
# just wrote (the self-reinforcing drift root). CURRENT_SID is the real source
# of truth post-v2.5.1, this is just extra protection during the migration window.
touch -t 197001010000 "$STATE_FILE" 2>/dev/null || true

# v2.1 P30: append transition log entry (non-fatal on failure).
# Helper lives in repo's scripts/ and is reached via __CLAUDE_CONFIG_DIR__
# (sed-substituted by set_claude.sh at deploy time) — the deployed
# ~/.claude/hooks/ dir has no scripts/ sibling.
HELPER_SCRIPT="__CLAUDE_CONFIG_DIR__/scripts/_transition_log_helper.py"
if [ -f "$HELPER_SCRIPT" ]; then
    python3 "$HELPER_SCRIPT" "$SDIR" "$SID" "$OLD_STATUS" "$NEW" "$EVENT" "$REASON" "$TS" \
        || echo "[transition.sh] log helper failed (non-fatal)" >&2
fi

# v2.1 P26/P28: after switching state, echo the full detailed pipeline
# (states/<state>.md) so AI sees the step-by-step walkthrough + completion
# criteria immediately, not just the thin per-turn router header.
# Mapping: STATUS → states/ filename (EXECUTE_LOOP → execute, others lowercase)
case "$NEW" in
    BOOT)         STATE_DOC="boot.md" ;;
    PREPARE)      STATE_DOC="prepare.md" ;;
    REFLECT)      STATE_DOC="reflect.md" ;;
    EXECUTE_LOOP) STATE_DOC="execute.md" ;;
    RECORDING)    STATE_DOC="recording.md" ;;
    END)          STATE_DOC="end.md" ;;
    *)            STATE_DOC="" ;;
esac
if [ -n "$STATE_DOC" ]; then
    # P36: states/ files read from repo via __CLAUDE_CONFIG_DIR__ (sed-substituted at deploy time).
    NEW_SPEC="__CLAUDE_CONFIG_DIR__/content/rules/states/$STATE_DOC"
    if [ -f "$NEW_SPEC" ]; then
        echo ""
        echo "=== Full pipeline for $NEW (states/$STATE_DOC) ==="
        echo ""
        cat "$NEW_SPEC"
    fi
fi

