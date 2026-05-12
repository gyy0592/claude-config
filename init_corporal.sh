#!/bin/bash
# ██████████████████████████████████████████████████████
# init_corporal.sh — Military camp initialization script
# Usage: init_corporal.sh <absolute path to working directory>
# Function: checks militar_camp/, creates bulletin boards (if not exist),
#           auto-determines Corporal number, generates three-file archive set
# ██████████████████████████████████████████████████████

WORK_DIR="${1:-.}"
# v2: template directory is now relative to repo root where script lives (init_corporal.sh is at repo root, dirname gives repo root directly)
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$REPO_ROOT/content/templates"
CAMP_DIR="$WORK_DIR/militar_camp"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Military camp init script — init_corporal.sh"
echo " Working directory: $WORK_DIR"
echo " Timestamp: $TIMESTAMP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: Check and create militar_camp/
if [ ! -d "$CAMP_DIR" ]; then
    mkdir -p "$CAMP_DIR"
    cp "$TEMPLATE_DIR/warning_board.md"  "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/reward_board.md"   "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/traitor.md"        "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/README.md"         "$CAMP_DIR/" 2>/dev/null || true
    echo "[INIT] ✅ Created militar_camp/ + 4 bulletin boards (warning/reward/traitor/README)"
else
    echo "[INIT] militar_camp/ already exists, skipping bulletin board creation"
fi

# Step 2: Determine Corporal number
NEXT_NUM=1
while [ -d "$CAMP_DIR/corporal_$NEXT_NUM" ]; do
    NEXT_NUM=$((NEXT_NUM + 1))
done

CORPORAL_DIR="$CAMP_DIR/corporal_$NEXT_NUM"
mkdir -p "$CORPORAL_DIR"
echo "[INIT] Corporal number: ${NEXT_NUM}"

# Step 3: Generate three-file archive set (replace placeholder X → actual number, timestamp → current time)
# corporal_status.md
sed "s/Corporal X/Corporal ${NEXT_NUM}/g" "$TEMPLATE_DIR/corporal_status.md" | \
    sed "s/YYYY-MM-DD HH:MM UTC/$TIMESTAMP/g" | \
    sed "s/<X-1>/$((NEXT_NUM - 1))/g" \
    > "$CORPORAL_DIR/corporal_status.md"

# corporal_action.md
sed "s/Corporal X/Corporal ${NEXT_NUM}/g" "$TEMPLATE_DIR/corporal_action.md" | \
    sed "s/YYYY-MM-DD HH:MM UTC/$TIMESTAMP/g" \
    > "$CORPORAL_DIR/corporal_action.md"

# corporal_situation.md
sed "s/Corporal X/Corporal ${NEXT_NUM}/g" "$TEMPLATE_DIR/corporal_situation.md" \
    > "$CORPORAL_DIR/corporal_situation.md"

echo "[INIT] ✅ Created three-file archive set:"
echo "        $CORPORAL_DIR/corporal_status.md"
echo "        $CORPORAL_DIR/corporal_action.md"
echo "        $CORPORAL_DIR/corporal_situation.md"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Corporal ${NEXT_NUM} archive ready"
echo " Path: $CORPORAL_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Claude must (within 30 seconds):"
echo "  1. Copy the Commander's instructions verbatim into corporal_status.md"
echo "  2. Append the first [BOARD_READ] entry to corporal_action.md"
echo "  3. Only then begin executing the task"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
