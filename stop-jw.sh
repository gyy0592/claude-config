#!/bin/bash
# 关闭纪委：从 ~/.claude/settings.json 移除 disciplinary_check.sh Stop hook 条目

python3 - <<PYEOF
import json, os, sys

settings_path = os.path.expanduser("~/.claude/settings.json")

try:
    with open(settings_path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print("[stop-jw] settings.json not found or invalid, nothing to remove")
    sys.exit(0)

hooks = cfg.get("hooks", {})

# ── 移除 Stop hook ──
stop_hooks = hooks.get("Stop", [])
before_count = len(stop_hooks)
new_stop_hooks = [
    entry for entry in stop_hooks
    if not (
        isinstance(entry, dict) and
        any(
            "disciplinary_check.sh" in h.get("command", "")
            for h in entry.get("hooks", [])
            if isinstance(h, dict)
        )
    )
]

if new_stop_hooks:
    hooks["Stop"] = new_stop_hooks
elif "Stop" in hooks and len(new_stop_hooks) < before_count:
    del hooks["Stop"]

# ── 移除 PostToolUse capture hook（如果还在）──
pt_hooks = hooks.get("PostToolUse", [])
new_pt_hooks = [
    entry for entry in pt_hooks
    if not (
        isinstance(entry, dict) and
        any(
            "jw-capture-session" in h.get("command", "")
            for h in entry.get("hooks", [])
            if isinstance(h, dict)
        )
    )
]
if new_pt_hooks:
    hooks["PostToolUse"] = new_pt_hooks
elif "PostToolUse" in hooks and len(new_pt_hooks) < len(pt_hooks):
    del hooks["PostToolUse"]

# 若 hooks 仅剩空键则不删除（保留其他 hook 类型）
with open(settings_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

removed = before_count - len(new_stop_hooks)
if removed > 0:
    print(f"[stop-jw] Removed {removed} disciplinary_check.sh Stop hook entry(ies)")
else:
    print("[stop-jw] No disciplinary_check.sh Stop hook found, nothing to remove")
print(f"[stop-jw] settings.json updated: {settings_path}")
PYEOF

# ── 清理 session 绑定文件 ──
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
rm -f "$PROJECT_DIR/.humanize/jw-session-id" 2>/dev/null || true
rm -f "$PROJECT_DIR/.humanize/.pending-jw-session" 2>/dev/null || true
echo "[stop-jw] session 绑定已清除"
