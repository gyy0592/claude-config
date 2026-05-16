#!/usr/bin/env bash
# new_task.sh — initialize a project-level workspace + per-task goal.md.
#
# Usage: bash <claude-config-dir>/scripts/new_task.sh <task_name>
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

if [[ $# -lt 1 ]]; then
  err_both "usage: bash ${BASH_SOURCE[0]} <task_name>"
  err_both "  example: bash ${BASH_SOURCE[0]} v4_audit"
  exit 2
fi

TASK_NAME="$1"
if ! [[ "$TASK_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  err_both "[new_task] error: task name must be [a-zA-Z0-9_-]+, got '$TASK_NAME'"
  exit 2
fi

WS="$PWD/workspace"
TASK_DIR="${WS}/${TASK_NAME}"
if [[ -d "$TASK_DIR" ]]; then
  err_both "[new_task] error: ${TASK_DIR} already exists — refusing to overwrite"
  exit 1
fi

mkdir -p "$TASK_DIR"

# 1. Per-task goal.md (always)
gsrc="${TPL_DIR}/goal.md"
if [[ -f "$gsrc" ]]; then
  cp "$gsrc" "${TASK_DIR}/goal.md"
else
  err_both "[new_task] warn: template ${gsrc} missing, creating empty goal.md"
  : > "${TASK_DIR}/goal.md"
fi

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
