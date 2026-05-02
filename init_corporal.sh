#!/bin/bash
# ██████████████████████████████████████████████████████
# init_corporal.sh — 军营初始化脚本
# 用法: init_corporal.sh <工作目录绝对路径>
# 功能: 检查 militar_camp/，创建公告板（若不存在），
#       自动确定下士编号，生成三件套档案
# ██████████████████████████████████████████████████████

WORK_DIR="${1:-.}"
TEMPLATE_DIR="$HOME/.claude/rules/templates"
CAMP_DIR="$WORK_DIR/militar_camp"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 军营初始化脚本 — init_corporal.sh"
echo " 工作目录: $WORK_DIR"
echo " 时间戳: $TIMESTAMP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: 检查并创建 militar_camp/
if [ ! -d "$CAMP_DIR" ]; then
    mkdir -p "$CAMP_DIR"
    cp "$TEMPLATE_DIR/warning_board.md"  "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/reward_board.md"   "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/traitor.md"        "$CAMP_DIR/"
    cp "$TEMPLATE_DIR/README.md"         "$CAMP_DIR/" 2>/dev/null || true
    echo "[INIT] ✅ 创建 militar_camp/ + 4份公告板（warning/reward/traitor/README）"
else
    echo "[INIT] militar_camp/ 已存在，跳过公告板创建"
fi

# Step 2: 确定下士编号
NEXT_NUM=1
while [ -d "$CAMP_DIR/corporal_$NEXT_NUM" ]; do
    NEXT_NUM=$((NEXT_NUM + 1))
done

CORPORAL_DIR="$CAMP_DIR/corporal_$NEXT_NUM"
mkdir -p "$CORPORAL_DIR"
echo "[INIT] 下士编号：${NEXT_NUM}号"

# Step 3: 生成三件套（替换占位符 X → 实际编号，时间戳 → 当前时间）
# corporal_status.md
sed "s/X号下士/${NEXT_NUM}号下士/g" "$TEMPLATE_DIR/corporal_status.md" | \
    sed "s/YYYY-MM-DD HH:MM UTC/$TIMESTAMP/g" | \
    sed "s/<X-1>/$((NEXT_NUM - 1))/g" \
    > "$CORPORAL_DIR/corporal_status.md"

# corporal_action.md
sed "s/X号下士/${NEXT_NUM}号下士/g" "$TEMPLATE_DIR/corporal_action.md" | \
    sed "s/YYYY-MM-DD HH:MM UTC/$TIMESTAMP/g" \
    > "$CORPORAL_DIR/corporal_action.md"

# corporal_situation.md
sed "s/X号下士/${NEXT_NUM}号下士/g" "$TEMPLATE_DIR/corporal_situation.md" \
    > "$CORPORAL_DIR/corporal_situation.md"

echo "[INIT] ✅ 创建三件套："
echo "        $CORPORAL_DIR/corporal_status.md"
echo "        $CORPORAL_DIR/corporal_action.md"
echo "        $CORPORAL_DIR/corporal_situation.md"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ${NEXT_NUM}号下士档案就绪"
echo " 路径: $CORPORAL_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Claude 接下来必须（30秒内）："
echo "  1. 在 corporal_status.md 逐字填写指挥官命令原文"
echo "  2. 在 corporal_action.md 追加第一条 [BOARD_READ]"
echo "  3. 才能开始执行任务"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
