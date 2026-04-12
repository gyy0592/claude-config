#!/bin/bash
# Fix: support OpenRouter model names (containing / and :) and config.toml-only mode
# Affects: loop-common.sh, loop-codex-stop-hook.sh, ask-codex.sh, setup-rlcr-loop.sh
# Branch: gyy0592/humanize@barrysdev
#
# What this patch does:
#   1. Relaxes model validation regex to allow / : + (OpenRouter model names)
#   2. Removes gpt-/o[0-9] prefix restriction
#   3. Makes -m flag conditional: omitted when model is empty, so codex uses config.toml
#   4. Makes codex review model args conditional too
#   5. Changes default model from "gpt-5.4" to "" (empty = use config.toml)
#   6. Fixes MODEL:EFFORT parser: split on last colon only if suffix is valid effort
#      (prevents nvidia/nemotron-...:free being parsed as model=nvidia/nemotron effort=free)
#
# Usage:
#   bash patches/fix-humanize-openrouter-model.sh
#
# To configure your model, edit ~/.codex/config.toml or use:
#   ./08_switch_codex_model.sh

set -euo pipefail

patched=0
skipped=0
failed=0

# ============================================================
# Patch 1: hooks/lib/loop-common.sh
#   - Relax regex to allow / : +
#   - Remove gpt-/o[0-9] prefix check
#   - Change default from gpt-5.4 to empty
# ============================================================
patch_loop_common() {
    local f="$1"

    # Check if already patched (our comment is the marker)
    if grep -q 'Empty string means.*config.toml' "$f" 2>/dev/null; then
        echo "SKIP (already patched): $f"
        skipped=$((skipped + 1))
        return
    fi

    local tmp
    tmp=$(mktemp)

    awk '
    # Replace the old restrictive regex validation
    /\^[[]a-zA-Z0-9._-[]]/ && /cfg_codex_model/ && /Invalid/ {
        sub(/\^\[a-zA-Z0-9\._-\]\+\$/, "^[a-zA-Z0-9._/:+-]+$")
        print
        next
    }

    # Remove the gpt-/o[0-9] prefix restriction block (3 lines: elif + 2 echo + assignment)
    /cfg_codex_model.*gpt-\|o\[0-9\]/ { skip_prefix=1; next }
    skip_prefix && /Must start with a Codex model prefix/ { next }
    skip_prefix && /Ignoring configured codex_model/ { next }
    skip_prefix && /cfg_codex_model=""/ { skip_prefix=0; next }
    skip_prefix && /^[[:space:]]*_cfg_codex_model=""/ { skip_prefix=0; next }

    # Replace the default assignment line
    /DEFAULT_CODEX_MODEL=.*cfg_codex_model:-gpt-5\.4/ {
        print "# Empty string means \"use ~/.codex/config.toml default\" (needed for OpenRouter models)"
        print "DEFAULT_CODEX_MODEL=\"${DEFAULT_CODEX_MODEL:-${_cfg_codex_model:-}}\""
        next
    }

    { print }
    ' "$f" > "$tmp"

    if grep -q 'config.toml default' "$tmp"; then
        cp "$tmp" "$f"
        echo "PATCHED: $f"
        patched=$((patched + 1))
    else
        echo "ERROR: patch failed for $f" >&2
        failed=$((failed + 1))
    fi
    rm -f "$tmp"
}

# ============================================================
# Patch 2: hooks/loop-codex-stop-hook.sh
#   - Allow empty model in validation
#   - Make -m conditional
#   - Make codex review model args conditional
# ============================================================
patch_stop_hook() {
    local f="$1"

    if grep -q 'omit -m so codex uses' "$f" 2>/dev/null; then
        echo "SKIP (already patched): $f"
        skipped=$((skipped + 1))
        return
    fi

    local tmp
    tmp=$(mktemp)

    awk '
    # Fix model fallback to allow empty
    /CODEX_EXEC_MODEL=.*STATE_CODEX_MODEL:-\$DEFAULT_CODEX_MODEL/ {
        gsub(/\$DEFAULT_CODEX_MODEL/, "${DEFAULT_CODEX_MODEL:-}")
        print
        next
    }

    # Fix validation: allow empty or relaxed regex
    /CODEX_EXEC_MODEL.*\^[[]a-zA-Z0-9._-[]]/ {
        print "if [[ -n \"$CODEX_EXEC_MODEL\" && ! \"$CODEX_EXEC_MODEL\" =~ ^[a-zA-Z0-9._/:+-]+$ ]]; then"
        next
    }

    # Make codex exec -m conditional
    /CODEX_EXEC_ARGS=\("-m" "\$CODEX_EXEC_MODEL"\)/ {
        print "# When model is empty, omit -m so codex uses ~/.codex/config.toml default"
        print "CODEX_EXEC_ARGS=()"
        print "if [[ -n \"$CODEX_EXEC_MODEL\" ]]; then"
        print "    CODEX_EXEC_ARGS+=(\"-m\" \"$CODEX_EXEC_MODEL\")"
        print "fi"
        next
    }

    # Make codex review model args conditional
    /CODEX_REVIEW_ARGS=\("-c" "model=\$\{CODEX_REVIEW_MODEL\}"/ {
        print "# When model is empty, omit model overrides so codex uses config.toml default"
        print "CODEX_REVIEW_ARGS=()"
        print "if [[ -n \"$CODEX_REVIEW_MODEL\" ]]; then"
        print "    CODEX_REVIEW_ARGS+=(\"-c\" \"model=${CODEX_REVIEW_MODEL}\" \"-c\" \"review_model=${CODEX_REVIEW_MODEL}\")"
        print "fi"
        next
    }

    { print }
    ' "$f" > "$tmp"

    if grep -q 'omit -m so codex uses' "$tmp"; then
        cp "$tmp" "$f"
        echo "PATCHED: $f"
        patched=$((patched + 1))
    else
        echo "ERROR: patch failed for $f" >&2
        failed=$((failed + 1))
    fi
    rm -f "$tmp"
}

# ============================================================
# Shared: Fix MODEL:EFFORT parser in any script
#   Old: split on first colon (breaks nvidia/...:free)
#   New: split on last colon, only if suffix is valid effort
# ============================================================
patch_model_effort_parser() {
    local f="$1"

    if grep -q 'suffix is a valid effort level' "$f" 2>/dev/null; then
        return 0  # already patched
    fi

    # Check if the old pattern exists
    if ! grep -q 'CODEX_MODEL=.*%%:\*' "$f" 2>/dev/null; then
        return 0  # no old pattern to fix
    fi

    local tmp
    tmp=$(mktemp)

    awk '
    /# Parse MODEL:EFFORT format/ {
        print "            # Parse MODEL:EFFORT format"
        print "            # Use last : as separator, but only if the suffix is a valid effort level"
        print "            # This handles OpenRouter names like nvidia/nemotron-3-super-120b-a12b:free"
        getline  # skip old comment line
        # Now read and replace the if/then/else/fi block
        getline  # if [[ "$2" == *:* ]]; then
        print "            _last_part=\"${2##*:}\""
        print "            if [[ \"$2\" == *:* && \"$_last_part\" =~ ^(xhigh|high|medium|low|none|minimal)$ ]]; then"
        getline  # CODEX_MODEL=...
        print "                CODEX_MODEL=\"${2%:*}\""
        getline  # CODEX_EFFORT=...
        print "                CODEX_EFFORT=\"$_last_part\""
        getline  # else
        getline  # CODEX_MODEL="$2"
        getline  # CODEX_EFFORT=...
        getline  # fi
        print "            else"
        print "                CODEX_MODEL=\"$2\""
        print "                CODEX_EFFORT=\"$DEFAULT_CODEX_EFFORT\""
        print "            fi"
        next
    }
    { print }
    ' "$f" > "$tmp"

    if grep -q 'suffix is a valid effort level' "$tmp"; then
        cp "$tmp" "$f"
        echo "  PATCHED (parser): $f"
        patched=$((patched + 1))
    fi
    rm -f "$tmp"
}

# ============================================================
# Patch 3: scripts/ask-codex.sh
#   - Allow empty model in validation
#   - Make -m conditional
# ============================================================
patch_ask_codex() {
    local f="$1"

    if grep -q 'omit -m so codex uses' "$f" 2>/dev/null; then
        echo "SKIP (already patched): $f"
        skipped=$((skipped + 1))
        return
    fi

    local tmp
    tmp=$(mktemp)

    awk '
    # Fix validation: allow empty or relaxed regex
    /CODEX_MODEL.*\^[[]a-zA-Z0-9._-[]]/ && /Invalid|invalid/ {
        print "if [[ -n \"$CODEX_MODEL\" && ! \"$CODEX_MODEL\" =~ ^[a-zA-Z0-9._/:+-]+$ ]]; then"
        next
    }

    # Make -m conditional
    /CODEX_EXEC_ARGS=\("-m" "\$CODEX_MODEL"\)/ {
        print "# When model is empty, omit -m so codex uses ~/.codex/config.toml default"
        print "CODEX_EXEC_ARGS=()"
        print "if [[ -n \"$CODEX_MODEL\" ]]; then"
        print "    CODEX_EXEC_ARGS+=(\"-m\" \"$CODEX_MODEL\")"
        print "fi"
        next
    }

    { print }
    ' "$f" > "$tmp"

    if grep -q 'omit -m so codex uses' "$tmp"; then
        cp "$tmp" "$f"
        echo "PATCHED: $f"
        patched=$((patched + 1))
    else
        echo "ERROR: patch failed for $f" >&2
        failed=$((failed + 1))
    fi
    rm -f "$tmp"
}

# ============================================================
# Patch 4: scripts/setup-rlcr-loop.sh
#   - Allow empty model default
#   - Relax validation regex
# ============================================================
patch_setup_rlcr() {
    local f="$1"

    if grep -q 'Allow empty.*config.toml' "$f" 2>/dev/null; then
        echo "SKIP (already patched): $f"
        skipped=$((skipped + 1))
        return
    fi

    local tmp
    tmp=$(mktemp)

    awk '
    # Fix default assignment to allow empty
    /^CODEX_MODEL="\$DEFAULT_CODEX_MODEL"/ {
        print "CODEX_MODEL=\"${DEFAULT_CODEX_MODEL:-}\""
        next
    }

    # Replace "Only alphanumeric" comment with new one
    /^# Only alphanumeric, hyphen, underscore, dot allowed/ {
        print "# Allow empty (uses config.toml default) or alphanumeric, hyphen, underscore, dot, slash, colon, plus"
        next
    }

    # Fix validation: allow empty or relaxed regex
    /CODEX_MODEL.*\^[[]a-zA-Z0-9\._-[]]/ {
        print "if [[ -n \"$CODEX_MODEL\" && ! \"$CODEX_MODEL\" =~ ^[a-zA-Z0-9._/:+-]+$ ]]; then"
        next
    }

    { print }
    ' "$f" > "$tmp"

    if grep -q 'Allow empty.*config.toml' "$tmp"; then
        cp "$tmp" "$f"
        echo "PATCHED: $f"
        patched=$((patched + 1))
    else
        echo "ERROR: patch failed for $f" >&2
        failed=$((failed + 1))
    fi
    rm -f "$tmp"
}

# ============================================================
# Main: find and patch all humanize installations
# ============================================================

echo "=== Patching humanize for OpenRouter model support ==="
echo ""

found_any=false

while IFS= read -r -d '' common_file; do
    found_any=true
    base_dir=$(dirname "$(dirname "$(dirname "$common_file")")")  # hooks/lib/loop-common.sh -> lib -> hooks -> plugin root

    echo "--- Found installation: $base_dir ---"

    patch_loop_common "$common_file"

    stop_hook="$base_dir/hooks/loop-codex-stop-hook.sh"
    [[ -f "$stop_hook" ]] && patch_stop_hook "$stop_hook"

    ask_codex="$base_dir/scripts/ask-codex.sh"
    [[ -f "$ask_codex" ]] && patch_ask_codex "$ask_codex"

    setup_rlcr="$base_dir/scripts/setup-rlcr-loop.sh"
    [[ -f "$setup_rlcr" ]] && patch_setup_rlcr "$setup_rlcr"

    # Fix MODEL:EFFORT parser in all scripts that have it
    for script in \
        "$base_dir/scripts/ask-codex.sh" \
        "$base_dir/scripts/setup-rlcr-loop.sh" \
        "$base_dir/scripts/setup-pr-loop.sh"; do
        [[ -f "$script" ]] && patch_model_effort_parser "$script"
    done

    echo ""
done < <(find ~/.claude/plugins -path "*/hooks/lib/loop-common.sh" -print0 2>/dev/null)

if [[ "$found_any" == false ]]; then
    echo "No humanize installation found under ~/.claude/plugins -- nothing to patch."
else
    echo "Done: $patched patched, $skipped already up-to-date, $failed failed."
fi
