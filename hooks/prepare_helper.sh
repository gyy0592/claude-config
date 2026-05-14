#!/usr/bin/env bash
# prepare_helper.sh — main calls this during PREPARE to:
#   1. List candidate artifacts under $PWD/workspace/<task>/ + .barry_workflow/
#   2. Emit a cache_hit_map YAML stub (one row per artifact, hit: UNKNOWN) for
#      main to fill in (YES/NO) based on its own KV-cache self-report.
#   3. Echo a prompt-reinforcement checklist (4 elements: observable, cadence,
#      reflection, completion) for main to verify against the user instruction.
#
# Tunables (v2.1 P13): see content/rules/workflow_config.yaml
#   prompt_reinforce.required_elements  → 4-element checklist printed below
set -euo pipefail

CWD="${PWD}"
STATE_DIR="${CWD}/.barry_workflow"
WORKSPACE_DIR="${CWD}/workspace"

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
for f in "$STATE_DIR"/state_*.md "$STATE_DIR"/action_*.md "${CWD}/CLAUDE.md" "${CWD}/goal.md"; do
    [ -f "$f" ] && artifacts+=("$f")
done

if [ "${#artifacts[@]}" -eq 0 ]; then
    echo "  # (no candidate artifacts found under workspace/ or .barry_workflow/)"
else
    for f in "${artifacts[@]}"; do
        rel="${f#${CWD}/}"
        sig="$(sha1sum "$f" 2>/dev/null | awk '{print substr($1,1,12)}')"
        echo "  ${rel}: {hit: UNKNOWN, sig: ${sig}, must_read_if_no: true}"
    done
fi

echo ""
echo "## prompt-reinforcement check (4 elements)"
echo ""
cat <<'EOF'
For the current user instruction, verify ALL four are present. If any is missing,
write [PROMPT_REINFORCED] in action_<sid>.md noting the gap, then ask the user
OR proceed with an assumed default + explicit caveat.

  [ ] observable     — what signal proves success? (file count / pid alive / output text)
  [ ] cadence        — how often to check? (every N min / on completion / event-driven)
  [ ] reflection     — when to spawn REFLECT subagent? (pre-task / on-anomaly / post-task)
  [ ] completion     — when to stop? (deliverable / time-bound / user-confirmed)
EOF
