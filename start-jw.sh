#!/bin/bash
# 启动纪委：把 disciplinary_check.sh 注册为 Claude Code Stop hook（幂等）
# 用法: start-jw.sh [--interval <秒>]
# 关闭: stop-jw.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JW_DIR="/tmp/claude_jw"
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$JW_DIR"

DISCIPLINARY="$SCRIPT_DIR/disciplinary_check.sh"
if [ ! -x "$DISCIPLINARY" ]; then
    echo "ERROR: disciplinary_check.sh not found at $DISCIPLINARY" >&2
    exit 1
fi

# 解析参数
INTERVAL=300
while [[ $# -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 重置 last_check 为 0（触发立即首次审查）
echo "0" > "$JW_DIR/last_check"
echo "$INTERVAL" > "$JW_DIR/interval"
echo "[start-jw $(date -u +%H:%M:%SZ)] Reset last_check=0, interval=$INTERVAL" >> "$JW_DIR/disciplinary.log" 2>/dev/null || true

# ── 幂等写入 Stop hook + PostToolUse hook 到 settings.json ──
HOOK_CMD="bash $DISCIPLINARY"
CAPTURE_CMD="bash $SCRIPT_DIR/jw-capture-session.sh"
python3 - <<PYEOF
import json, os, sys

settings_path = os.path.expanduser("~/.claude/settings.json")
hook_cmd = "$HOOK_CMD"
capture_cmd = "$CAPTURE_CMD"

try:
    with open(settings_path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

hooks = cfg.setdefault("hooks", {})

# ── Stop hook（幂等）──
stop_hooks = hooks.setdefault("Stop", [])
already_present = any(
    isinstance(entry, dict) and any(
        "disciplinary_check.sh" in h.get("command", "")
        for h in entry.get("hooks", [])
        if isinstance(h, dict)
    )
    for entry in stop_hooks
)

if already_present:
    print("[start-jw] Stop hook already present in settings.json, no change needed")
else:
    stop_hooks.append({
        "hooks": [
            {"type": "command", "command": hook_cmd}
        ]
    })
    print(f"[start-jw] Stop hook registered: {hook_cmd}")

# ── PostToolUse hook（幂等）用于捕获 session_id ──
pt_hooks = hooks.setdefault("PostToolUse", [])
capture_present = any(
    isinstance(entry, dict) and any(
        "jw-capture-session" in h.get("command", "")
        for h in entry.get("hooks", [])
        if isinstance(h, dict)
    )
    for entry in pt_hooks
)

if capture_present:
    print("[start-jw] PostToolUse capture hook already present, no change needed")
else:
    pt_hooks.append({
        "hooks": [
            {"type": "command", "command": capture_cmd}
        ]
    })
    print(f"[start-jw] PostToolUse capture hook registered: {capture_cmd}")

with open(settings_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"[start-jw] settings.json updated: {settings_path}")
PYEOF

# ── 创建 session 绑定信号文件 ──
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$PROJECT_ROOT/.humanize"
echo "$PROJECT_ROOT/.humanize/jw-session-id" > "$PROJECT_ROOT/.humanize/.pending-jw-session"

echo "[start-jw] 纪委已启动（Stop hook 模式）"
echo "  disciplinary_check.sh 将在每次 Claude 回复结束后自动触发"
echo "  时间门控: 默认 ${INTERVAL}s，有死罪时 120s"
echo "  日志: $JW_DIR/disciplinary.log"
echo "  关闭: $SCRIPT_DIR/stop-jw.sh"
echo "  等待下一个工具调用后 session_id 将自动绑定..."
