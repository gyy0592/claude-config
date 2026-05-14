#!/usr/bin/env bash
# cleanup_v1.sh — purge v1 residuals from a deployed claude-config env.
#
# Run on the machine where set_claude.sh has been deployed:
#   cd ~/Programs/claude-config && bash cleanup_v1.sh
#
# Removes:
#   - v1 hook scripts under ~/.claude/hooks/
#   - stale runtime dirs: ~/.claude_status/, ~/.claude/system_override.txt
#   - v1 shell-rc wrapper residuals (--append-system-prompt-file lines)
#
# Does NOT touch:
#   - ~/.claude/rules/violation.md, lessons.md (preserved; back them up if paranoid)
#   - the repo (use `git rm` separately for tracked v1 files — already done upstream)
#   - settings.json hook registrations (set_claude.sh prunes those on next deploy)
#
# Idempotent — safe to re-run.

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
echo "── cleanup_v1.sh ──────────────────────────────────"
echo "target: $CLAUDE_DIR"
echo ""

# ── v1 hook files ────────────────────────────────────
V1_HOOKS=(
    inject_decrees.sh
    inject_decrees_to_subagent.sh
    reset_session_status.sh
    stop_self_audit.sh
)

removed_any=0
for h in "${V1_HOOKS[@]}"; do
    if [ -e "$HOOKS_DIR/$h" ]; then
        rm -f "$HOOKS_DIR/$h"
        echo "[cleanup] removed $HOOKS_DIR/$h"
        removed_any=1
    fi
done
[ "$removed_any" = "0" ] && echo "[cleanup] no v1 hooks present"

# ── v1 runtime artifacts (workspace-level .claude_status replaced by .barry_workflow) ──
# Only remove the global one in $HOME — leave per-workspace dirs alone (user may want logs).
if [ -d "$HOME/.claude_status" ]; then
    rm -rf "$HOME/.claude_status"
    echo "[cleanup] removed $HOME/.claude_status (v1 session-status dir)"
fi

# ── v1 override file (set_claude.sh also deletes this; here for safety) ──
if [ -f "$CLAUDE_DIR/system_override.txt" ]; then
    rm -f "$CLAUDE_DIR/system_override.txt"
    echo "[cleanup] removed $CLAUDE_DIR/system_override.txt"
fi

# ── v1 shell wrapper residuals ───────────────────────
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    if grep -qE 'append-system-prompt-file|system_override\.txt' "$rc"; then
        cp "$rc" "$rc.v1cleanup.bak.$(date +%s)"
        # Cross-platform sed -i.
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i '/append-system-prompt-file/d;/system_override\.txt/d' "$rc"
        else
            sed -i '' '/append-system-prompt-file/d;/system_override\.txt/d' "$rc"
        fi
        echo "[cleanup] purged v1 lines from $rc (backup at $rc.v1cleanup.bak.*)"
    fi
done

# ── settings.json hook-list pruning is handled by set_claude.sh on next deploy ──
echo ""
echo "[cleanup] done. Next step: re-run 'bash set_claude.sh' to refresh settings.json hook registrations."
