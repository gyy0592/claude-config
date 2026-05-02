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

if len(new_stop_hooks) == before_count:
    print("[stop-jw] No disciplinary_check.sh Stop hook found, nothing to remove")
    sys.exit(0)

if new_stop_hooks:
    hooks["Stop"] = new_stop_hooks
elif "Stop" in hooks:
    del hooks["Stop"]

# 若 hooks 仅剩空键则不删除（保留其他 hook 类型）
with open(settings_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

removed = before_count - len(new_stop_hooks)
print(f"[stop-jw] Removed {removed} disciplinary_check.sh Stop hook entry(ies)")
print(f"[stop-jw] settings.json updated: {settings_path}")
PYEOF
