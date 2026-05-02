#!/bin/bash
# jw-capture-session.sh — PostToolUse hook（一次性）
# 捕获 Claude Code 传来的 session_id，写入 .humanize/jw-session-id
# 完成后自动注销自身 PostToolUse hook

# 读 stdin（PostToolUse hook JSON）
HOOK_INPUT=$(cat)
SESSION_ID=$(printf '%s' "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")

# 检查信号文件是否存在
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PENDING_FILE="$PROJECT_DIR/.humanize/.pending-jw-session"

if [ ! -f "$PENDING_FILE" ]; then
    exit 0  # 没有待绑定的信号，直接退出
fi

if [ -z "$SESSION_ID" ]; then
    exit 0  # 没有 session_id，退出
fi

# 读取目标写入路径
TARGET_FILE=$(cat "$PENDING_FILE" 2>/dev/null || echo "")
if [ -z "$TARGET_FILE" ]; then
    exit 0
fi

# 写入 session_id（失败时保留 pending 文件，等下次重试）
if ! echo "$SESSION_ID" > "$TARGET_FILE" 2>/dev/null; then
    echo "[纪委][ERROR] 写入 $TARGET_FILE 失败，pending 文件保留等待重试" >&2
    exit 1
fi

# 写入成功后删除信号文件（一次性消费）
rm -f "$PENDING_FILE"

# 注销自身 PostToolUse hook（已完成使命）
python3 - <<PYEOF
import json, os, tempfile
settings_path = os.path.expanduser("~/.claude/settings.json")
try:
    with open(settings_path) as f:
        cfg = json.load(f)
except Exception:
    exit(0)
hooks = cfg.get("hooks", {})
pt_hooks = hooks.get("PostToolUse", [])
new_pt = [e for e in pt_hooks if not any(
    "jw-capture-session" in h.get("command","")
    for h in e.get("hooks",[]) if isinstance(h,dict)
)]
if len(new_pt) < len(pt_hooks):
    if new_pt:
        hooks["PostToolUse"] = new_pt
    else:
        del hooks["PostToolUse"]
    # 原子写（防进程崩溃损坏 settings.json）
    tmp = settings_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    os.replace(tmp, settings_path)
PYEOF

echo "[纪委] session_id 已绑定：$SESSION_ID → $TARGET_FILE"
