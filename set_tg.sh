#!/usr/bin/env bash
# set_tg.sh — 配置指挥官 Telegram 通知频道
# 作用：生成 ~/.claude/tg_send.sh（本地凭证文件，不提交 GitHub）
# 用法：bash set_tg.sh
#       或：bash set_tg.sh <BOT_TOKEN> <CHAT_ID>

set -euo pipefail

DEST="$HOME/.claude/tg_send.sh"

# 从参数或交互读取凭证
if [[ $# -ge 2 ]]; then
    BOT_TOKEN="$1"
    CHAT_ID="$2"
else
    echo "=== Telegram Bot 配置 ==="
    echo "凭证只保存在本机 $DEST，不写入 GitHub。"
    echo ""
    read -rp "请输入 Bot Token: " BOT_TOKEN
    read -rp "请输入 Chat ID:   " CHAT_ID
fi

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo "错误：Bot Token 和 Chat ID 不能为空。" >&2
    exit 1
fi

# 生成 tg_send.sh（嵌入凭证，本地专用）
cat > "$DEST" << SCRIPT
#!/usr/bin/env bash
# ~/.claude/tg_send.sh — 自动生成，禁止手工编辑，禁止提交 GitHub
# 用法：~/.claude/tg_send.sh "消息内容"
set -euo pipefail
MSG="\${1:-（无消息内容）}"
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \\
    -d chat_id="${CHAT_ID}" \\
    --data-urlencode "text=\$MSG" > /dev/null
SCRIPT

chmod +x "$DEST"

echo ""
echo "✓ 配置完成：$DEST 已生成"
echo "测试命令：~/.claude/tg_send.sh \"测试消息\""
