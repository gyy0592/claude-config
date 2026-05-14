#!/usr/bin/env bash
# inject_router.sh — slim router injection, v4 P2 replacement for inject_decrees.sh.
# Triggered by UserPromptSubmit. Source-of-truth lives in ~/.claude/rules/router.md
# (built from content/rules/router.md by set_claude.sh). Hook just cats the file.
# Easy to edit: change router.md, rerun set_claude.sh, no script edit needed.
set -euo pipefail

ROUTER_FILE="$HOME/.claude/rules/router.md"
if [ -f "$ROUTER_FILE" ]; then
    cat "$ROUTER_FILE"
else
    echo "[ROUTER] router.md missing at $ROUTER_FILE — rerun set_claude.sh"
fi
