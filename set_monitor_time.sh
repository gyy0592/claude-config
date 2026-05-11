#!/usr/bin/env bash
# set_monitor_time.sh — 动态调整军方监控周期
# 用法：bash set_monitor_time.sh <分钟数>
# 改字眼即可，部署仍由 set_claude.sh / set_codex.sh 完成。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_MD="$SCRIPT_DIR/content/CLAUDE.md"
AGENTS_MD="$SCRIPT_DIR/content/AGENTS.md"
WORKFLOWS_MD="$SCRIPT_DIR/content/memory/workflows.md"

# 参数校验
if [ $# -ne 1 ]; then
  echo "用法：bash set_monitor_time.sh <分钟数>（1-1440）" >&2
  exit 1
fi
NEW=$1
if ! [[ "$NEW" =~ ^[0-9]+$ ]] || [ "$NEW" -lt 1 ] || [ "$NEW" -gt 1440 ]; then
  echo "错误：分钟数必须是 1-1440 之间的正整数，收到「$NEW」" >&2
  exit 1
fi

# 当前监控周期检测（从 CLAUDE.md 第一个匹配「每 N 分钟」提取 N）
OLD=$(grep -oE '每 [0-9]+ 分钟' "$CLAUDE_MD" | head -1 | grep -oE '[0-9]+' || true)
if [ -z "$OLD" ]; then
  echo "错误：未在 $CLAUDE_MD 找到「每 N 分钟」字眼，无法检测当前周期。" >&2
  exit 1
fi

if [ "$OLD" = "$NEW" ]; then
  echo "已经是 $OLD 分钟，无需修改"
  exit 0
fi

# 三个目标文件 sed 替换
for f in "$CLAUDE_MD" "$AGENTS_MD" "$WORKFLOWS_MD"; do
  sed -i \
    -e "s|每 ${OLD} 分钟|每 ${NEW} 分钟|g" \
    -e "s|${OLD} 分钟监控一次|${NEW} 分钟监控一次|g" \
    -e "s|${OLD} 分钟回看|${NEW} 分钟回看|g" \
    -e "s|+ ${OLD} 分钟」|+ ${NEW} 分钟」|g" \
    "$f"
done

echo "监控周期已从 ${OLD} 分钟改为 ${NEW} 分钟。请运行 bash set_claude.sh && bash set_codex.sh 部署到 ~/.claude/ ~/.codex/。"
