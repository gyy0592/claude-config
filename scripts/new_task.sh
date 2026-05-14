#!/usr/bin/env bash
# new_task.sh — initialize a project-level workspace/<task>/ scaffold.
#
# Usage: bash <claude-config-dir>/scripts/new_task.sh <task_name>
#
# Run from inside your project directory. Creates:
#   $PWD/workspace/<task_name>/
#     ├── goal.md               (user-controlled, AI reads only)
#     ├── bitter_lessons.md     (AI appends L-N)
#     ├── successful_fixes.md   (AI appends FIX-N)
#     └── attempts_ledger.md    (AI appends ATT-N)
#
# rule_violations.md is created by the AI on first W-N entry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TPL_DIR="${REPO_ROOT}/content/templates"

if [[ $# -lt 1 ]]; then
  echo "usage: bash ${BASH_SOURCE[0]} <task_name>" >&2
  echo "  example: bash ${BASH_SOURCE[0]} v4_audit" >&2
  exit 2
fi

TASK_NAME="$1"
if ! [[ "$TASK_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "[new_task] error: task name must be [a-zA-Z0-9_-]+, got '$TASK_NAME'" >&2
  exit 2
fi

DST="$PWD/workspace/${TASK_NAME}"
if [[ -d "$DST" ]]; then
  echo "[new_task] error: ${DST} already exists — refusing to overwrite" >&2
  exit 1
fi

mkdir -p "$DST"
for f in goal.md bitter_lessons.md successful_fixes.md attempts_ledger.md; do
  src="${TPL_DIR}/${f}"
  if [[ ! -f "$src" ]]; then
    echo "[new_task] warn: template ${src} missing, skip" >&2
    continue
  fi
  cp "$src" "${DST}/${f}"
done

echo "[new_task] ✓ created ${DST}"
echo "[new_task]   files:"
ls -1 "${DST}" | sed 's/^/[new_task]     /'
echo "[new_task] next: edit ${DST}/goal.md to describe the task."
