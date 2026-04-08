#!/bin/bash
# Fix: session_id never written when CLAUDE_PLUGIN_ROOT has trailing slash
# Affects: loop-post-bash-hook.sh in all locally installed humanize versions
# See: https://github.com/humania-org/humanize/issues/67
# Compatible: macOS and Linux

# Marker: unique enough to avoid false positives from unrelated tr -s uses
PATCH_MARKER="HOOK_COMMAND | tr -s '/'"

patched=0
skipped=0
found=0

while IFS= read -r -d '' hook; do
    found=$((found + 1))

    if grep -q "$PATCH_MARKER" "$hook"; then
        echo "SKIP (already patched): $hook"
        skipped=$((skipped + 1))
        continue
    fi

    tmp=$(mktemp)

    # Insert the normalization block after the closing fi of the empty-HOOK_COMMAND
    # early-exit block. The anchor is the fi that follows 'exit 0' inside
    # 'if [[ -z "$HOOK_COMMAND" ]]; then'. We track state to insert only once,
    # after that specific fi, not any other fi in the file.
    #
    # awk is used instead of sed to avoid macOS/Linux sed -i incompatibilities.
    awk '
        /if \[\[ -z "\$HOOK_COMMAND" \]\]; then/ && !done { in_early_exit=1 }
        in_early_exit && /^[[:space:]]*fi[[:space:]]*$/ && !done {
            print
            in_early_exit=0
            done=1
            print ""
            print "    # Normalize consecutive slashes (trailing slash in CLAUDE_PLUGIN_ROOT"
            print "    # produces double slashes in tool_input.command, breaking IS_SETUP"
            print "    # comparison and preventing session_id from being written)."
            print "    # See: https://github.com/humania-org/humanize/issues/67"
            print "    HOOK_COMMAND=$(printf '"'"'%s'"'"' \"$HOOK_COMMAND\" | tr -s '"'"'/'"'"')"
            print "    COMMAND_SIGNATURE=$(printf '"'"'%s'"'"' \"$COMMAND_SIGNATURE\" | tr -s '"'"'/'"'"')"
            next
        }
        { print }
    ' "$hook" > "$tmp"

    if grep -q "$PATCH_MARKER" "$tmp"; then
        cp "$tmp" "$hook"
        echo "PATCHED: $hook"
        patched=$((patched + 1))
    else
        echo "ERROR: patch failed for $hook (anchor line not found?)" >&2
    fi
    rm -f "$tmp"
done < <(find ~/.claude/plugins -name "loop-post-bash-hook.sh" -print0 2>/dev/null)

if [[ $found -eq 0 ]]; then
    echo "No humanize installation found under ~/.claude/plugins -- nothing to patch."
else
    echo "Done: $patched patched, $skipped already up-to-date, $found total."
fi
