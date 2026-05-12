#!/usr/bin/env bash
# init_soldier.sh — Private self-initialization script
# First step for a Private upon arrival: call this script to auto-create directory and template files.
#
# Usage: bash __CLAUDE_CONFIG_DIR__/init_soldier.sh <Corporal number> <Private number> [working directory]
#
# Example: bash /path/to/init_soldier.sh 1 4 /home/user/myproject
#          → creates /home/user/myproject/militar_camp/corporal_1/number4/
#          → generates soldier_status.md + soldier_action.md

set -euo pipefail

CORPORAL_NUM="${1:?Usage: init_soldier.sh <Corporal number> <Private number> [working directory]}"
SOLDIER_NUM="${2:?Usage: init_soldier.sh <Corporal number> <Private number> [working directory]}"
WORKDIR="${3:-$(pwd)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# v2: template directory is now relative to repo root where script lives (init_soldier.sh is at repo root, SCRIPT_DIR is the repo root)
TEMPLATE_DIR="$SCRIPT_DIR/content/templates"
SOLDIER_DIR="$WORKDIR/militar_camp/corporal_${CORPORAL_NUM}/number${SOLDIER_NUM}"

# Create directory
mkdir -p "$SOLDIER_DIR"

# Generate soldier_action.md (from template, replace number placeholders)
if [ ! -f "$SOLDIER_DIR/soldier_action.md" ]; then
    sed \
        -e "s/Private Y/Private ${SOLDIER_NUM}/g" \
        -e "s/corporal_X/corporal_${CORPORAL_NUM}/g" \
        -e "s/numberY/number${SOLDIER_NUM}/g" \
        "$TEMPLATE_DIR/soldier_action.md" > "$SOLDIER_DIR/soldier_action.md"
    echo "✓ soldier_action.md generated"
else
    echo "- soldier_action.md already exists, skipping"
fi

# Generate soldier_status.md (from template, replace number placeholders)
if [ ! -f "$SOLDIER_DIR/soldier_status.md" ]; then
    sed \
        -e "s/Private Y/Private ${SOLDIER_NUM}/g" \
        -e "s/Corporal X/Corporal ${CORPORAL_NUM}/g" \
        "$TEMPLATE_DIR/soldier_status.md" > "$SOLDIER_DIR/soldier_status.md"
    echo "✓ soldier_status.md generated (waiting for Private to fill in full prompt text)"
else
    echo "- soldier_status.md already exists, skipping"
fi

echo ""
echo "Private ${SOLDIER_NUM} initialization complete: $SOLDIER_DIR"
echo "Next step: paste the received Agent prompt verbatim into soldier_status.md"
