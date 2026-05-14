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

# ── P35: hand-rolled mini yaml parser ────────────────────────────────────────
# read_config <yaml_path> <dotted_key>
# Reads a simple (no-anchors, no-flow) yaml file and returns the value for the
# given 1- or 2-level dotted key (e.g. "execute_loop.failure_budget").
# Returns empty string and exit non-zero if file missing or key not found.
# Caller should fall back to a hardcoded default + print a warning to stderr.
read_config() {
    local yaml="$1" key="$2"
    [ -f "$yaml" ] || return 1
    local top="${key%%.*}"
    local sub="${key#*.}"
    if [ "$top" = "$key" ]; then
        # single-level key
        sed -n "s/^${key}:[[:space:]]*\(.*\)$/\1/p" "$yaml" | head -1 | tr -d "'\"" | tr -d '[:space:]'
    else
        # two-level: find "top:" block, then find "sub:" inside it
        awk -v top="$top" -v sub="$sub" '
            $0 ~ ("^"top":") { in_top=1; next }
            in_top && /^[a-zA-Z_]/ { in_top=0 }
            in_top && $0 ~ ("^[[:space:]]+"sub":") {
                sub("^[[:space:]]+"sub":[[:space:]]*", "")
                gsub(/["\047]/, "")
                gsub(/[[:space:]]/, "")
                print
                exit
            }
        ' "$yaml"
    fi
}

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
