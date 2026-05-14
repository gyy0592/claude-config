#!/usr/bin/env bash
# transition.sh — FSM state mutator. Called by main as:
#   bash transition.sh <event>  [--reason=<...>]
# Events: BOOT_DONE | PREPARE_DONE | REFLECT_DONE | EXECUTE_EXIT
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

EVENT="${1:-}"
REASON=""
shift || true
for arg in "$@"; do
    case "$arg" in
        --reason=*) REASON="${arg#--reason=}" ;;
    esac
done

if [ -z "$EVENT" ]; then
    echo "usage: transition.sh <BOOT_DONE|PREPARE_DONE|REFLECT_DONE|EXECUTE_EXIT> [--reason=...]" >&2
    exit 2
fi

CWD="${PWD}"
STATE_FILE="$(latest_state_file "$CWD" || true)"
if [ -z "$STATE_FILE" ]; then
    echo "transition.sh: no state file under $(barry_root "$CWD")" >&2
    exit 1
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Capture OLD status BEFORE the Python mutator rewrites state.md
OLD_STATUS="$(grep '^current_status:' "$STATE_FILE" | awk '{print $2}' | tr -d '[:space:]')"

# Map event → new status
case "$EVENT" in
    BOOT_DONE)     NEW=PREPARE ;;
    PREPARE_DONE)  NEW=REFLECT ;;
    REFLECT_DONE)  NEW=EXECUTE_LOOP ;;
    EXECUTE_EXIT)  NEW=REFLECT ;;
    *) echo "transition.sh: unknown event $EVENT" >&2; exit 2 ;;
esac

# Derive session dir and SID from state file path (layout: .barry_workflow/<sid>/state.md)
SDIR="$(dirname "$STATE_FILE")"
SID="$(basename "$SDIR")"

python3 - "$STATE_FILE" "$NEW" "$EVENT" "$REASON" "$TS" <<'PY'
import sys, re, pathlib
path, new_status, event, reason, ts = sys.argv[1:]
src = pathlib.Path(path).read_text()
m = re.search(r"```yaml\n---YAML---\n(.*?)\n---YAML---\n```", src, re.S)
if not m:
    print(f"transition.sh: YAML block not found in {path}", file=sys.stderr)
    sys.exit(1)
yaml_body = m.group(1)
# Naive line-based rewrite to avoid yaml dep.
out_lines = []
for line in yaml_body.splitlines():
    if line.startswith("current_status:"):
        out_lines.append(f"current_status: {new_status}")
    elif line.startswith("last_transition:"):
        out_lines.append(f"last_transition: {{event: {event}, at: {ts}, reason: \"{reason}\"}}")
    elif line.startswith("stage_history:"):
        # Normalise stage_history: [] → empty list, then append new item.
        out_lines.append("stage_history:")
        # Drop pre-existing inline-empty marker if present.
        out_lines.append(f"  - {{event: {event}, to: {new_status}, at: {ts}, reason: \"{reason}\"}}")
    else:
        out_lines.append(line)
new_yaml = "\n".join(out_lines)
new_src = src[:m.start(1)] + new_yaml + src[m.end(1):]
pathlib.Path(path).write_text(new_src)
print(f"{event} → {new_status}")
PY

# v2.1 P30: append transition log entry (non-fatal on failure)
HELPER_SCRIPT="$(dirname "$0")/../scripts/_transition_log_helper.py"
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
    END)          STATE_DOC="end.md" ;;
    *)            STATE_DOC="" ;;
esac
if [ -n "$STATE_DOC" ]; then
    NEW_SPEC="$HOME/.claude/rules/states/$STATE_DOC"
    if [ -f "$NEW_SPEC" ]; then
        echo ""
        echo "=== Full pipeline for $NEW (states/$STATE_DOC) ==="
        echo ""
        cat "$NEW_SPEC"
    fi
fi

