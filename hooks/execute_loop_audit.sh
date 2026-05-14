#!/usr/bin/env bash
# execute_loop_audit.sh — quick audit of the current EXECUTE_LOOP discipline.
# main can call this at any point inside the loop (or before EXECUTE_EXIT) to
# verify [PLAN]/[OBSERVE] pairing and failure-budget consumption.
#
# Tunables (v2.1 P13): see content/rules/workflow_config.yaml
#   execute_loop.failure_budget  → "$ANOM_CNT -ge 3" check below
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

CWD="${PWD}"
ACTION_FILE="$(latest_action_file "$CWD" || true)"
if [ -z "$ACTION_FILE" ]; then
    echo "no action.md under $(barry_root "$CWD")" >&2
    exit 1
fi

PLAN_CNT=$(grep -cE '^\[PLAN\]' "$ACTION_FILE" || true)
OBS_CNT=$(grep -cE '^\[OBSERVE\]'  "$ACTION_FILE" || true)
ANOM_CNT=$(grep -ciE '^\[OBSERVE\].*(refuted|anomaly|fail(ed|ure)?|stuck|unchanged|timeout|exit code [1-9]|traceback|oom|killed|crash|hang)' "$ACTION_FILE" || true)

echo "# EXECUTE_LOOP audit ($(date -u +%H:%M:%SZ))"
echo "  action file: ${ACTION_FILE#${CWD}/}"
echo "  [PLAN] count:     ${PLAN_CNT}"
echo "  [OBSERVE] count:  ${OBS_CNT}"
echo "  refuted/anomaly:  ${ANOM_CNT}"
echo ""

if [ "$PLAN_CNT" -ne "$OBS_CNT" ]; then
    echo "⚠ PLAN/OBSERVE mismatch (${PLAN_CNT} vs ${OBS_CNT}). Each [PLAN] must be paired with one [OBSERVE]."
fi
if [ "$ANOM_CNT" -ge 3 ]; then
    echo "⚠ Failure budget exhausted (${ANOM_CNT} anomalies). Per failure_stop.md: call transition.sh EXECUTE_EXIT --reason=bug and report to user, UNLESS \$PWD/CLAUDE.md AUTH override is in effect."
fi
