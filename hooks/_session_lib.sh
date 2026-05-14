# _session_lib.sh — shared helpers for Barry's workflow session files.
# Sourced by session_boot.sh / transition.sh / prepare_helper.sh /
# execute_loop_audit.sh / pretooluse_short_nudge.sh.
#
# v2.1 P22: per-session subdirectory layout:
#   $PWD/.barry_workflow/<sid>/{state,action,nudge_counters}.{md,json}
#   $PWD/.barry_workflow/<sid>/reflection_*.md
#   $PWD/.barry_workflow/<sid>/agent_<aid>/...
#
# No `set -e` here — this file is meant to be sourced.

# session_dir <cwd> <sid> → echoes <cwd>/.barry_workflow/<sid>
session_dir() {
    local cwd="$1"
    local sid="$2"
    printf '%s/.barry_workflow/%s' "$cwd" "$sid"
}

# barry_root <cwd> → echoes <cwd>/.barry_workflow
barry_root() {
    printf '%s/.barry_workflow' "$1"
}

# latest_session_dir <cwd> → echoes most-recently-modified <sid> subdir path.
# Empty output if none. Excludes non-dir entries.
latest_session_dir() {
    local cwd="$1"
    local root
    root="$(barry_root "$cwd")"
    [ -d "$root" ] || return 0
    # Prefer directories. Fall back gracefully if none exist.
    local d
    d="$(ls -1dt "$root"/*/ 2>/dev/null | head -1 || true)"
    [ -z "$d" ] && return 0
    # Strip trailing slash
    printf '%s' "${d%/}"
}

# latest_state_file <cwd> → echoes path to newest state.md across all <sid> subdirs.
# Falls back to legacy flat $cwd/.barry_workflow/state_*.md if no subdir layout found.
latest_state_file() {
    local cwd="$1"
    local root
    root="$(barry_root "$cwd")"
    [ -d "$root" ] || return 0
    local f
    f="$(ls -1t "$root"/*/state.md 2>/dev/null | head -1 || true)"
    if [ -z "$f" ]; then
        f="$(ls -1t "$root"/state_*.md 2>/dev/null | head -1 || true)"
    fi
    [ -n "$f" ] && printf '%s' "$f"
}

# latest_action_file <cwd> → echoes path to newest action.md.
latest_action_file() {
    local cwd="$1"
    local root
    root="$(barry_root "$cwd")"
    [ -d "$root" ] || return 0
    local f
    f="$(ls -1t "$root"/*/action.md 2>/dev/null | head -1 || true)"
    if [ -z "$f" ]; then
        f="$(ls -1t "$root"/action_*.md 2>/dev/null | head -1 || true)"
    fi
    [ -n "$f" ] && printf '%s' "$f"
}
