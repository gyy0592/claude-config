#!/usr/bin/env bash
# new_task.sh — initialize a project-level workspace + per-task goal.md.
#
# Usage: bash <claude-config-dir>/scripts/new_task.sh --name <task_name> [--goal "..."] [--constraint "..."]
#        compat: bash <claude-config-dir>/scripts/new_task.sh <task_name>
#
# Run from inside your project directory.
#
# Layout (v2, shared ledgers):
#   $PWD/workspace/                  ← shared across all tasks
#     ├── bitter_lessons.md
#     ├── successful_fixes.md
#     ├── attempts_ledger.md
#     ├── rule_violations.md
#     └── <task_name>/
#         └── goal.md                ← per-task target
#
# Behavior:
#   - Always creates $PWD/workspace/<task_name>/goal.md from template
#   - Shared ledgers are seeded ONCE: only copied if absent at $PWD/workspace/
#     so subsequent tasks accumulate into the same files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TPL_DIR="${REPO_ROOT}/content/templates"

# v2.5.2 F6 fix: source _session_lib.sh for err_both (dual-channel error).
# Self-contained fallback in case lib is missing (e.g. running from a partial
# checkout) — keeps the script usable even if the hook layer isn't deployed.
LIB="${REPO_ROOT}/hooks/_session_lib.sh"
if [[ -f "$LIB" ]]; then
  # shellcheck disable=SC1090
  . "$LIB"
fi
if ! declare -F err_both >/dev/null 2>&1; then
  err_both() { printf '%s\n' "$*" >&2; printf '%s\n' "$*"; }
fi

TASK_NAME=""
GOAL_TEXT=""
CONSTRAINT_TEXT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       TASK_NAME="$2"; shift 2 ;;
    --goal)       GOAL_TEXT="$2"; shift 2 ;;
    --constraint) CONSTRAINT_TEXT="$2"; shift 2 ;;
    -*)           err_both "unknown flag $1"; exit 2 ;;
    *)            TASK_NAME="$1"; shift ;;   # backward-compat positional
  esac
done

if [[ -z "$TASK_NAME" ]]; then
  err_both "usage: bash ${BASH_SOURCE[0]} --name <task_name> [--goal \"...\"] [--constraint \"...\"]"
  err_both "  compat: bash ${BASH_SOURCE[0]} <task_name>"
  exit 2
fi

if ! [[ "$TASK_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  err_both "[new_task] error: task name must be [a-zA-Z0-9_-]+, got '$TASK_NAME'"
  exit 2
fi

if [[ -z "$GOAL_TEXT" ]]; then
  err_both "error: --goal is required"
  err_both "usage: bash ${BASH_SOURCE[0]} --name <task_name> --goal \"...\" --constraint \"...\""
  exit 2
fi
if [[ -z "$CONSTRAINT_TEXT" ]]; then
  err_both "error: --constraint is required"
  err_both "usage: bash ${BASH_SOURCE[0]} --name <task_name> --goal \"...\" --constraint \"...\""
  exit 2
fi

WS="$PWD/workspace"
TASK_DIR="${WS}/${TASK_NAME}"
if [[ -d "$TASK_DIR" ]]; then
  err_both "[new_task] error: ${TASK_DIR} already exists — refusing to overwrite"
  exit 1
fi

mkdir -p "$TASK_DIR"

# 1. Per-task 2-file layout: goal.md + constraint.md
# (v2.7.20: dropped current_task.md manifest — state.md fields are self-describing.)

# 1a. goal.md — template + user --goal text replacing the placeholder paragraph
gsrc="${TPL_DIR}/goal.md"
if [[ -f "$gsrc" ]]; then
  cp "$gsrc" "${TASK_DIR}/goal.md"
else
  err_both "[new_task] warn: template ${gsrc} missing, creating bare goal.md"
  cat > "${TASK_DIR}/goal.md" << 'BAREGOAL'
# Goal

(One paragraph: what must be achieved by end of this task.)

## Success Criteria

(Observable, checkable criteria — how to verify the goal is complete.)
BAREGOAL
fi
# Replace the placeholder paragraph under "# Goal" with the user's --goal text.
python3 - "${TASK_DIR}/goal.md" "$GOAL_TEXT" << 'PYG'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text()
goal_text = sys.argv[2]
# Replace any parenthesized placeholder right after "# Goal" header up to the next "##" heading.
new = re.sub(
    r'(^# Goal\s*\n)\(.*?\)\s*\n',
    lambda m: m.group(1) + "\n" + goal_text.rstrip() + "\n\n",
    txt, count=1, flags=re.DOTALL | re.MULTILINE,
)
p.write_text(new)
PYG

# 1b. constraint.md — template + user --constraint text replacing placeholder block
csrc="${TPL_DIR}/constraint.md"
if [[ -f "$csrc" ]]; then
  cp "$csrc" "${TASK_DIR}/constraint.md"
else
  err_both "[new_task] warn: template ${csrc} missing, creating bare constraint.md"
  cat > "${TASK_DIR}/constraint.md" << 'BARECON'
# Constraints

(Hard constraints — things that MUST NOT be violated.)
BARECON
fi
python3 - "${TASK_DIR}/constraint.md" "$CONSTRAINT_TEXT" << 'PYC'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text()
con_text = sys.argv[2]
# Replace the placeholder parenthesized block right after "# Constraints" header.
new = re.sub(
    r'(^# Constraints\s*\n)\(.*?\)\s*\n',
    lambda m: m.group(1) + "\n" + con_text.rstrip() + "\n",
    txt, count=1, flags=re.DOTALL | re.MULTILINE,
)
p.write_text(new)
PYC

# 2. Shared ledgers (only if absent — idempotent across tasks)
seeded=()
for f in bitter_lessons.md successful_fixes.md attempts_ledger.md; do
  dst="${WS}/${f}"
  src="${TPL_DIR}/${f}"
  if [[ -f "$dst" ]]; then
    continue
  fi
  if [[ ! -f "$src" ]]; then
    err_both "[new_task] warn: template ${src} missing, skip"
    continue
  fi
  cp "$src" "$dst"
  seeded+=("$f")
done
# rule_violations.md has no template; create empty if absent
if [[ ! -f "${WS}/rule_violations.md" ]]; then
  : > "${WS}/rule_violations.md"
  seeded+=("rule_violations.md")
fi

# Update current_goal / current_constraint in active state.md (best-effort).
# v2.7.20: dropped current_task field — state.md's 2 path fields are
# self-describing; current_task.md manifest was redundant indirection.
if declare -F latest_state_file >/dev/null 2>&1; then
  ACTIVE_STATE="$(latest_state_file "$PWD" 2>/dev/null || true)"
  if [[ -n "$ACTIVE_STATE" && -f "$ACTIVE_STATE" ]]; then
    SAFE_TASK_NAME="${TASK_NAME//[$'\n\r']/}"
    GOAL_REL="workspace/${SAFE_TASK_NAME}/goal.md"
    CON_REL="workspace/${SAFE_TASK_NAME}/constraint.md"
    sed -i "s|^current_goal:.*|current_goal: \"${GOAL_REL}\"|" "$ACTIVE_STATE" 2>/dev/null || true
    if grep -q '^current_constraint:' "$ACTIVE_STATE" 2>/dev/null; then
      sed -i "s|^current_constraint:.*|current_constraint: \"${CON_REL}\"|" "$ACTIVE_STATE" 2>/dev/null || true
    else
      sed -i "/^current_goal:/a current_constraint: \"${CON_REL}\"" "$ACTIVE_STATE" 2>/dev/null || true
    fi
    # Drop stale current_task line from older v2.7.19 deployments.
    sed -i '/^current_task:/d' "$ACTIVE_STATE" 2>/dev/null || true
    echo "[new_task] ✓ updated current_goal / current_constraint in ${ACTIVE_STATE}"
  fi
fi

echo "[new_task] ✓ task dir: ${TASK_DIR}"
echo "[new_task]   - goal.md (per-task, edit this to describe the task)"
if (( ${#seeded[@]} )); then
  echo "[new_task] ✓ shared ledgers seeded at ${WS}/ (first task in this repo):"
  for f in "${seeded[@]}"; do
    echo "[new_task]   - ${f}"
  done
else
  echo "[new_task] ✓ shared ledgers already present at ${WS}/ — not touched"
fi
echo "[new_task] next: edit ${TASK_DIR}/goal.md to describe the task."
