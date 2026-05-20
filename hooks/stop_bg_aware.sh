#!/usr/bin/env bash
# stop_bg_aware.sh — v2.7.21. Stop hook with bg-aware + self-reflect gate.
#
# Behavior:
# 1. Parse transcript for pending bg tasks (Agent run_in_background, Bash bg).
#    If any pending bg task → exit 0 silent allow. Claude session naturally
#    pauses; when bg task finishes Claude Code fires task_notification and
#    the next stop attempt re-enters this hook with no pending → normal flow.
# 2. bg settled → consult .barry_workflow/<sid>/stop_decision.json:
#    - stop=1 && reflect_rounds=5 → consume + allow.
#    - stop=0 → keep file + block ("not done, finish work first").
#    - else (-1 / missing) → create placeholder + block with self-reflect msg.
#       The msg also tells Claude: if you need to WAIT, mount a bg sleep task
#       (`bash -c 'sleep N && date >> /tmp/heartbeat' &` or write to a file
#       periodically); the hook will see bg pending and silent-allow stop.
#       NO wait_seconds / wait_until / sleep-then-block machinery in the hook.

set -u

CONFIG_DIR="__CLAUDE_CONFIG_DIR__"
LIB="$(dirname "$0")/_session_lib.sh"
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

input="$(cat 2>/dev/null || true)"
[ -z "$input" ] && exit 0

stop_hook_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
session_id=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // ""' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$cwd" ] && cwd="${PWD:-$(pwd)}"

# Sanitize session_id (BUG-04/05/19/22 fix): strip everything except [a-zA-Z0-9_-]
# to prevent path traversal in SDIR construction and command injection when
# session_id is embedded in instructional MSG text. Empty → fail-open exit.
session_id="${session_id//[^a-zA-Z0-9_-]/}"
[ -z "$session_id" ] && exit 0

# yaml stop_gate.enabled — default off; opt-in via workflow_config.yaml.
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

# Resolve grace-seconds threshold from yaml (default 120s = 2 min).
# An agent whose .output mtime is within grace_sec is treated as alive even
# when lsof finds no open fd — covers the lsof gap between intermittent writes.
# Dead agents whose last write is older than grace_sec + lsof dead → dropped.
GRACE_SEC=120
if [ -f "$YAML" ] && declare -F read_config >/dev/null 2>&1; then
    v="$(read_config "$YAML" "stop_gate.bg_grace_seconds" 2>/dev/null || true)"
    [ -n "${v:-}" ] && GRACE_SEC="$v"
fi

# Parse transcript: launched - completed bg ids, then liveness gate.
# BUG-S-R2-06/09 fix: cap total python+lsof wall-clock at 8s via `timeout` so
# a pathologically long pending set or stale NFS can't exceed Claude Code's
# hook timeout. On timeout, bg_state stays "none" (fall-through).
bg_state="none"
TIMEOUT_BIN="$(command -v timeout || true)"
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    bg_state=$(STALE_MIN="$STALE_MIN" GRACE_SEC="$GRACE_SEC" ${TIMEOUT_BIN:+$TIMEOUT_BIN 8} python3 - "$transcript_path" 2>/dev/null << 'PY'
import sys, json, os, time, re
path = sys.argv[1]
stale_sec = int(os.environ.get("STALE_MIN", "30")) * 60
grace_sec = int(os.environ.get("GRACE_SEC", "120"))

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
        # v2.7.11: lsof liveness probe + grace-window mtime fallback.
        #   - lsof exit 0 = at least one process has .output open → alive.
        #   - lsof no-fd + age < grace_sec (default 120s) → alive: covers the
        #     lsof fd gap between intermittent writes (agents write one line,
        #     close fd, compute, reopen → lsof blind window is milliseconds to
        #     seconds; 2-min grace comfortably covers it).
        #   - lsof no-fd + age >= grace_sec → dead: agent wrote > 2 min ago
        #     and no process holds the fd now → genuinely finished or crashed.
        # This tightens the v2.7.10 OR fix (which used stale_sec=30 min as
        # the mtime fallback window, causing up to 30-min false-positive for
        # recently-dead agents). Grace window reduces that to ≤ grace_sec.
        import subprocess, shutil
        lsof_bin = shutil.which('lsof')
        active = set()
        now = time.time()
        for tid in pending:
            ofile = os.path.join(tasks_dir, f"{tid}.output")
            # Just-launched (no .output yet) → assume alive.
            if not os.path.exists(ofile):
                active.add(tid); continue
            # mtime silence check.
            try:
                age = now - os.path.getmtime(ofile)
            except OSError:
                # Cannot stat → fail open as alive.
                active.add(tid); continue
            mtime_stale = age >= stale_sec
            # lsof liveness check (skip if lsof unavailable).
            if lsof_bin is None:
                lsof_alive = not mtime_stale  # fall back to mtime only
            else:
                try:
                    # BUG-11 fix: timeout=2s defends against stale NFS/FUSE
                    # where lsof can block for minutes waiting on kernel.
                    rc = subprocess.run(
                        [lsof_bin, ofile],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=2,
                    ).returncode
                    lsof_alive = (rc == 0)
                except subprocess.TimeoutExpired:
                    lsof_alive = True  # timeout → fail open
                except Exception:
                    lsof_alive = True  # fail open
            # lsof alive OR wrote within grace_sec → alive.
            # grace_sec (default 120s) covers lsof fd gap between intermittent
            # writes while keeping false-positive window tight (vs 30-min stale_sec).
            if lsof_alive or age < grace_sec:
                active.add(tid)
            # else: dead (lsof: no fd AND last write > grace_sec ago) → drop.
        pending = active

    print('pending' if pending else 'none')
except Exception:
    print('unknown')
PY
)
fi

# bg truly pending → silent allow stop; bg task notification will wake Claude.
if [ "$bg_state" = "pending" ]; then
    exit 0
fi

# bg settled: consult the self-reflect decision file.
SDIR="${cwd}/.barry_workflow/${session_id}"
DECISION_FILE="${SDIR}/stop_decision.json"

if [ -f "$DECISION_FILE" ] && [ -s "$DECISION_FILE" ]; then
    # BUG-R2-05 fix: validate JSON syntax first; non-JSON file → delete & recreate
    # to avoid permanent block deadlock. NOTE: must NOT use `jq -e empty` — the
    # `-e` flag returns 1 when output is empty/null, which `empty` filter always
    # produces, so valid JSON would be falsely flagged. Use plain `jq empty`.
    if ! jq empty "$DECISION_FILE" >/dev/null 2>&1; then
        rm -f "$DECISION_FILE" 2>/dev/null
    fi
fi
if [ -f "$DECISION_FILE" ] && [ -s "$DECISION_FILE" ]; then
    # BUG-15/47/72 fix: normalize stop value (true→1, false→0, accept int or string).
    # BUG-R2-04 fix: also accept JSON float forms 1.0 / 0.0.
    STOP_RAW=$(jq -r '.stop // -1' "$DECISION_FILE" 2>/dev/null)
    REFLECT_ROUNDS=$(jq -r '.reflect_rounds // 0' "$DECISION_FILE" 2>/dev/null)
    REASON=$(jq -r '.reason // ""' "$DECISION_FILE" 2>/dev/null)
    case "$STOP_RAW" in
        true|True|TRUE)            STOP_VAL="1" ;;
        false|False|FALSE)         STOP_VAL="0" ;;
        1|1.0)                     STOP_VAL="1" ;;
        0|0.0)                     STOP_VAL="0" ;;
        -1|-1.0)                   STOP_VAL="-1" ;;
        "")                        STOP_VAL="-1" ;;  # jq failure
        *)                         STOP_VAL="-1" ;;  # garbage
    esac

    # BUG-13/24 + BUG-R2-03 fix: regex bounded 1-9 digits (max 999_999_999) to
    # prevent integer-overflow bypass where `[ huge -lt 5 ]` exits 2 (false-negative).
    if [ "$STOP_VAL" = "1" ]; then
        if [[ "$REFLECT_ROUNDS" =~ ^[0-9]{1,9}$ ]]; then
            if [ "$REFLECT_ROUNDS" -lt 5 ]; then
                STOP_VAL="-1"
            fi
        else
            # Non-integer or overflow-range reflect_rounds → reject.
            STOP_VAL="-1"
        fi
    fi

    # BUG-S41 fix: REASON may contain shell metacharacters but we put it through
    # jq --arg below, which is safe. We do NOT use ${REASON} inside any eval'd
    # context here. Just embed in MSG which is then properly escaped by jq --arg.

    case "$STOP_VAL" in
        1)
            rm -f "$DECISION_FILE"
            exit 0
            ;;
        0)
            # Keep file so retry blocks immediately without new reflect cycle.
            MSG="[stop_gate] Self-reflect verdict: NOT done — reason: ${REASON}. Complete the remaining work, then Edit ${DECISION_FILE} with stop=1/reflect_rounds=5/all fields, and retry stop."
            jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
            exit 0
            ;;
        *)
            # -1 / invalid → fall through to self-reflect gate below.
            ;;
    esac
fi

# No usable decision → create placeholder + block + ask main to self-reflect.
# BUG-S33/S35/S92 fix: verify mkdir + SDIR is a directory before write; if not, fail-open.
if ! mkdir -p "$SDIR" 2>/dev/null || [ ! -d "$SDIR" ]; then
    # Can't create state dir → fail-open silent (don't deadlock the user).
    exit 0
fi
# BUG-S35 fix: DECISION_FILE accidentally being a directory → unlink first.
if [ -d "$DECISION_FILE" ]; then
    rmdir "$DECISION_FILE" 2>/dev/null || rm -rf "$DECISION_FILE" 2>/dev/null
fi
# BUG-R2-02 fix: if it's still a directory after rmdir/rm-rf, fail-open exit
# (don't deadlock with permanent block + no way to fix).
if [ -d "$DECISION_FILE" ]; then
    exit 0
fi
# BUG-17 / BUG-S26 / BUG-R2-01/06/07 fix: atomic write via mktemp + mv +
# EXIT trap to clean up on signal. mktemp uses O_EXCL so attacker can't
# pre-create the tmp path as a symlink.
if [ ! -f "$DECISION_FILE" ] || [ ! -s "$DECISION_FILE" ]; then
    INIT_TS=$(date +%s 2>/dev/null)
    # BUG-18 fix: if date fails, abort placeholder write (don't emit broken JSON).
    if ! [[ "$INIT_TS" =~ ^[0-9]+$ ]]; then
        exit 0
    fi
    TMP_FILE="$(mktemp "${SDIR}/.stop_decision.XXXXXX" 2>/dev/null)"
    if [ -z "$TMP_FILE" ] || [ ! -f "$TMP_FILE" ]; then
        exit 0  # mktemp failed (permission etc.) — fail-open
    fi
    # Always remove TMP_FILE on exit/signal.
    trap 'rm -f "$TMP_FILE" 2>/dev/null' EXIT INT TERM
    cat > "$TMP_FILE" << JSON
{
  "stop": -1,
  "_init_ts": ${INIT_TS},
  "reflect_rounds": 0,
  "all_constraints_met": "no",
  "all_goals_met": "no",
  "reason": "AWAITING — see hook message for OPTION A (mount a bg sleep task to wait) or OPTION B (5-field self-reflect)"
}
JSON
    if [ -s "$TMP_FILE" ]; then
        if ! mv -f "$TMP_FILE" "$DECISION_FILE" 2>/dev/null; then
            # mv failed (race or perm) — keep tmp file? No, drop it.
            rm -f "$TMP_FILE" 2>/dev/null
            exit 0  # fail-open
        fi
    else
        exit 0  # write produced nothing — fail-open
    fi
fi

GOAL_HINT=""
current_goal=$(grep -m1 '^current_goal:' "${SDIR}/state.md" 2>/dev/null | sed 's/^current_goal:[[:space:]]*//' | tr -d '"' | tr -d '\n' || true)
if [ -n "$current_goal" ]; then
    abs_goal="${cwd}/${current_goal}"
    [ -f "$abs_goal" ] && GOAL_HINT="goal.md: ${abs_goal} — READ IT before reflecting."
fi
if [ -z "$GOAL_HINT" ] && [ -d "${cwd}/workspace" ]; then
    FOUND_GOAL=$(find "${cwd}/workspace" -name "goal.md" -maxdepth 3 2>/dev/null | head -1)
    [ -n "$FOUND_GOAL" ] && GOAL_HINT="goal.md found at: ${FOUND_GOAL} — READ IT before reflecting."
fi
[ -z "$GOAL_HINT" ] && GOAL_HINT="No goal.md found — reconstruct goal from session context."

MSG="[stop_gate] bg settled. Before stopping, YOU must either wait or self-reflect.

OPTION A — If you need to WAIT (more work to do soon, but want a pause):
  Mount a bg heartbeat task that keeps the bg-detection alive, e.g.
    Bash(run_in_background=true, command=\"bash -c 'for i in {1..30}; do echo tick \$i \$(date) >> /tmp/heartbeat_${session_id}.log; sleep 1; done'\")
  Or a one-shot sleep:
    Bash(run_in_background=true, command=\"sleep 30\")
  Retry stop — the hook will see bg pending and silent-allow. When the bg
  task completes, Claude Code fires task_notification and you wake up.
  NO need to set any wait fields in the JSON — bg presence is the signal.

OPTION B — If work is done and you are ready to assess:
1. ${GOAL_HINT}
2. Run 5 rebuttal rounds (spawn Agent(run_in_background=true) once per round, read reply, repeat).
   Each round: ask 'did we fully achieve the goal? any constraint violated?'
3. After round 5 consensus, Edit ${DECISION_FILE} with ALL fields:
   (a) \"stop\": 1 (all goals met + no violations) OR 0 (incomplete)
   (b) \"reflect_rounds\": 5  (must be exactly 5 — hook rejects < 5)
   (c) \"all_constraints_met\": \"yes\" or \"no\"
   (d) \"all_goals_met\": \"yes\" or \"no\"
   (e) \"reason\": one-sentence summary
   (f) FACTS CHECK — before writing stop=1, answer: Are ALL your answers above
       [FACT] (directly observed this turn)? Any [INFERENCE] or [ASSUMPTION]?
       Did you exhaust every possible verification command? If any claim is not
       directly observed output — you CANNOT write stop=1.
4. Retry stop. Hook will consume the file and allow if stop=1 and reflect_rounds=5."

jq -n --arg r "$MSG" '{decision:"block", reason:$r}'
exit 0
