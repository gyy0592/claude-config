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

# Step 1: Check and create militar_camp/ + v2 5-file ledger system
# v2 NEW: 4 project-level ledger files (operation_log / attempts_ledger / bitter_lessons / successful_fixes)
# Global violation.md + lessons.md are deployed by set_claude.sh to ~/.claude/rules/ (auto-loaded by Claude every session)
if [ ! -d "$CAMP_DIR" ]; then
    mkdir -p "$CAMP_DIR"
    cp "$TEMPLATE_DIR/operation_log.md"     "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/attempts_ledger.md"   "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/bitter_lessons.md"    "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/successful_fixes.md"  "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/README.md"            "$CAMP_DIR/" 2>/dev/null || true
    echo "[INIT] ✅ Created militar_camp/ + v2 ledger files (operation_log/attempts_ledger/bitter_lessons/successful_fixes)"
else
    echo "[INIT] militar_camp/ already exists. Checking for missing v2 ledger files..."
    # Migration check: add missing v2 files without touching existing data
    for f in operation_log.md attempts_ledger.md bitter_lessons.md successful_fixes.md; do
        if [ ! -f "$CAMP_DIR/$f" ]; then
            cp "$TEMPLATE_DIR/$f" "$CAMP_DIR/"
            echo "[INIT] + Added missing v2 file: $f"
        fi
    done
    # Warn about deprecated files (don't delete; let user decide)
    for f in warning_board.md reward_board.md traitor.md; do
        if [ -f "$CAMP_DIR/$f" ]; then
            echo "[INIT] ⚠️  $f still exists — DEPRECATED in v2. Contents replaced by ~/.claude/rules/violation.md (global) + bitter_lessons.md/successful_fixes.md (project). Manual cleanup recommended."
        fi
    done
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
