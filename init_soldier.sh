#!/usr/bin/env bash
# init_soldier.sh — 列兵自初始化脚本
# 列兵到岗后第一步调用此脚本，自动创建目录和模板文件。
#
# 用法：bash __CLAUDE_CONFIG_DIR__/init_soldier.sh <下士编号> <列兵编号> [工作目录]
#
# 示例：bash /path/to/init_soldier.sh 1 4 /home/user/myproject
#        → 创建 /home/user/myproject/militar_camp/corporal_1/number4/
#        → 生成 soldier_status.md + soldier_action.md

set -euo pipefail

CORPORAL_NUM="${1:?用法：init_soldier.sh <下士编号> <列兵编号> [工作目录]}"
SOLDIER_NUM="${2:?用法：init_soldier.sh <下士编号> <列兵编号> [工作目录]}"
WORKDIR="${3:-$(pwd)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$HOME/.claude/rules/templates"
SOLDIER_DIR="$WORKDIR/militar_camp/corporal_${CORPORAL_NUM}/number${SOLDIER_NUM}"

# 创建目录
mkdir -p "$SOLDIER_DIR"

# 生成 soldier_action.md（从模板，替换编号占位符）
if [ ! -f "$SOLDIER_DIR/soldier_action.md" ]; then
    sed \
        -e "s/Y号列兵/${SOLDIER_NUM}号列兵/g" \
        -e "s/corporal_X/corporal_${CORPORAL_NUM}/g" \
        -e "s/numberY/number${SOLDIER_NUM}/g" \
        "$TEMPLATE_DIR/soldier_action.md" > "$SOLDIER_DIR/soldier_action.md"
    echo "✓ soldier_action.md 已生成"
else
    echo "- soldier_action.md 已存在，跳过"
fi

# 生成 soldier_status.md（从模板，替换编号占位符）
if [ ! -f "$SOLDIER_DIR/soldier_status.md" ]; then
    sed \
        -e "s/Y号列兵/${SOLDIER_NUM}号列兵/g" \
        -e "s/X号下士/${CORPORAL_NUM}号下士/g" \
        "$TEMPLATE_DIR/soldier_status.md" > "$SOLDIER_DIR/soldier_status.md"
    echo "✓ soldier_status.md 已生成（等待列兵填写 prompt 全文）"
else
    echo "- soldier_status.md 已存在，跳过"
fi

echo ""
echo "列兵 ${SOLDIER_NUM} 号初始化完成：$SOLDIER_DIR"
echo "下一步：在 soldier_status.md 粘贴收到的 Agent prompt 全文"
