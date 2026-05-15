#!/usr/bin/env bash
# prepare_helper.sh — main calls this during PREPARE to:
#   1. List candidate artifacts under $PWD/workspace/*.md (shared ledgers) + $PWD/workspace/<task>/goal.md + .barry_workflow/
#   2. Emit a cache_hit_map YAML stub (one row per artifact, hit: UNKNOWN) for
#      main to fill in (YES/NO) based on its own KV-cache self-report.
#   3. Echo a prompt-reinforcement checklist (4 elements: observable, cadence,
#      reflection, completion) for main to verify against the user instruction.
#
# Tunables (v2.1 P13): see content/rules/workflow_config.yaml
#   prompt_reinforce.required_elements  → 4-element checklist printed below
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

CWD="${PWD}"
WORKSPACE_DIR="${CWD}/workspace"
LATEST_SDIR="$(latest_session_dir "$CWD" || true)"

echo "# PREPARE helper — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
echo "## cache_hit_map stub (paste into state YAML, replace UNKNOWN with YES/NO)"
echo ""
echo "cache_hit_map:"

shopt -s nullglob
artifacts=()
if [ -d "$WORKSPACE_DIR" ]; then
    for f in "$WORKSPACE_DIR"/*/*.md "$WORKSPACE_DIR"/*.md; do
        [ -f "$f" ] && artifacts+=("$f")
    done
fi
if [ -n "$LATEST_SDIR" ]; then
    for f in "$LATEST_SDIR"/state.md "$LATEST_SDIR"/action.md; do
        [ -f "$f" ] && artifacts+=("$f")
    done
fi
for f in "${CWD}/CLAUDE.md" "${CWD}/goal.md"; do
    [ -f "$f" ] && artifacts+=("$f")
done
# v2.4 F2: deployed global ledgers — router asks model to grep their tags: every turn
for f in "$HOME/.claude/rules/violation.md" "$HOME/.claude/rules/lessons.md"; do
    [ -f "$f" ] && artifacts+=("$f")
done

if [ "${#artifacts[@]}" -eq 0 ]; then
    echo "  # (no candidate artifacts found under workspace/ or .barry_workflow/)"
else
    for f in "${artifacts[@]}"; do
        if [ "${f#${CWD}/}" != "$f" ]; then
            rel="${f#${CWD}/}"
        else
            rel="${f/#$HOME/\~}"
        fi
        sig="$(sha1sum "$f" 2>/dev/null | awk '{print substr($1,1,12)}')"
        echo "  ${rel}: {hit: UNKNOWN, sig: ${sig}, must_read_if_no: true}"
    done
fi

echo ""
# v2.1 P23 / P36: emit the prompt-reinforcement checklist from a maintainable .md
# file in the repo (not ~/.claude/rules/messages — that dir is no longer deployed).
MSG_DIR="__CLAUDE_CONFIG_DIR__/content/rules/messages"
CHECKLIST="$MSG_DIR/prepare_checklist.md"
if [ -f "$CHECKLIST" ]; then
    cat "$CHECKLIST"
else
    echo "## prompt-reinforcement check (4 elements)"
    echo "(prepare_checklist.md missing under $MSG_DIR — rerun set_claude.sh)"
fi
