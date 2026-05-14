#!/usr/bin/env bash
# session_boot.sh — UserPromptSubmit hook. Creates per-session state + action
# files under $PWD/.barry_workflow/<sid>/ if missing. Idempotent.
# v2.1 P22: per-session subdir layout.
# v2.1 P17: cross-session inherit (cache_hit_map carry-over from latest prior sid).
set -euo pipefail

# shellcheck source=_session_lib.sh
. "$(dirname "$0")/_session_lib.sh"

INPUT="$(cat || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$CWD" ] && CWD="${PWD:-$(pwd)}"
[ -z "$SID" ] && SID="$(date +%s)-noidshort"

# Heuristic: only create if .git or CLAUDE.md or workspace/ exists at $CWD.
if [ ! -d "${CWD}/.git" ] && [ ! -f "${CWD}/CLAUDE.md" ] && [ ! -d "${CWD}/workspace" ]; then
    exit 0
fi

SDIR="$(session_dir "$CWD" "$SID")"
STATE_FILE="${SDIR}/state.md"
ACTION_FILE="${SDIR}/action.md"

# P17 inherit: detect prior sid dirs BEFORE creating this one.
# Strategy:
#   - 0 prior dirs → fresh start
#   - 1 prior dir  → auto-inherit
#   - 2+ prior dirs → pick latest by mtime + log note
# Escape hatch: BARRY_FRESH_SESSION=1 skips inherit.
PRIOR_SDIR=""
PRIOR_COUNT=0
if [ "${BARRY_FRESH_SESSION:-0}" != "1" ] && [ -d "$(barry_root "$CWD")" ] && [ ! -d "$SDIR" ]; then
    while IFS= read -r d; do
        [ -z "$d" ] && continue
        PRIOR_COUNT=$((PRIOR_COUNT + 1))
    done < <(find "$(barry_root "$CWD")" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    if [ "$PRIOR_COUNT" -ge 1 ]; then
        PRIOR_SDIR="$(latest_session_dir "$CWD")"
    fi
fi

mkdir -p "$SDIR"

TEMPLATE_ROOT="__CLAUDE_CONFIG_DIR__/content/templates"
STATE_TPL="${TEMPLATE_ROOT}/state_template.md"
ACTION_TPL="${TEMPLATE_ROOT}/action_template.md"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DT="$(date -u +%Y-%m-%d)"

if [ ! -f "$STATE_FILE" ] && [ -f "$STATE_TPL" ]; then
    sed -e "s|__SID__|${SID}|g" -e "s|__TS__|${TS}|g" -e "s|__DATE__|${DT}|g" \
        "$STATE_TPL" > "$STATE_FILE"

    # P17 inherit: inject inherited_from + copy cache_hit_map from prior session.
    if [ -n "$PRIOR_SDIR" ] && [ -f "${PRIOR_SDIR}/state.md" ]; then
        OLD_SID="$(basename "$PRIOR_SDIR")"
        python3 - "$STATE_FILE" "${PRIOR_SDIR}/state.md" "$OLD_SID" "$PRIOR_COUNT" <<'PY' || true
import sys, re, pathlib
new_path, old_path, old_sid, count = sys.argv[1:]
new_src = pathlib.Path(new_path).read_text()
old_src = pathlib.Path(old_path).read_text()

# Pull cache_hit_map block from old state.md (best-effort: indented YAML rows).
m = re.search(r"^cache_hit_map:\s*\n((?:[ \t].*\n)+)", old_src, re.M)
inherited_block = m.group(0).rstrip() + "\n" if m else ""

def patch_yaml(src):
    mm = re.search(r"(```yaml\n---YAML---\n)(.*?)(\n---YAML---\n```)", src, re.S)
    if not mm:
        return src
    body = mm.group(2)
    if "inherited_from:" not in body:
        body = body.rstrip() + f"\ninherited_from: {old_sid}\ninherited_count: {count}"
    if inherited_block and re.search(r"^cache_hit_map:\s*\{\s*\}\s*$", body, re.M):
        body = re.sub(r"^cache_hit_map:\s*\{\s*\}\s*$", inherited_block.rstrip(), body, count=1, flags=re.M)
    return src[:mm.start(2)] + body + src[mm.end(2):]

pathlib.Path(new_path).write_text(patch_yaml(new_src))
PY
    fi
fi
if [ ! -f "$ACTION_FILE" ] && [ -f "$ACTION_TPL" ]; then
    sed -e "s|__SID__|${SID}|g" -e "s|__DATE__|${DT}|g" \
        "$ACTION_TPL" > "$ACTION_FILE"
    if [ -n "$PRIOR_SDIR" ]; then
        OLD_SID="$(basename "$PRIOR_SDIR")"
        printf '\n[INHERIT] new session inherits from %s (latest of %s prior session(s)). cache_hit_map carried.\n' \
            "$OLD_SID" "$PRIOR_COUNT" >> "$ACTION_FILE"
    fi
fi

# v2.3 — idempotently seed shared project ledgers under $CWD/workspace/.
# Only fires if workspace/ exists; copies any missing ledger from templates.
# Per-task goal.md is still created by scripts/new_task.sh (needs task name).
WORKSPACE="${CWD}/workspace"
if [ -d "$WORKSPACE" ]; then
    for f in bitter_lessons.md successful_fixes.md attempts_ledger.md; do
        dst="${WORKSPACE}/${f}"
        src="${TEMPLATE_ROOT}/${f}"
        if [ ! -f "$dst" ] && [ -f "$src" ]; then
            cp "$src" "$dst"
        fi
    done
    # rule_violations.md has no template — create empty if absent.
    [ ! -f "${WORKSPACE}/rule_violations.md" ] && : > "${WORKSPACE}/rule_violations.md"
fi

exit 0
