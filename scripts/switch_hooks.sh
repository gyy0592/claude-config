#!/usr/bin/env bash
# switch_hooks.sh — toggle barry-workflow v2 hooks on/off in ~/.claude/settings.json.
#
# Use cases:
#   - Doing a trivial one-shot task and don't want the FSM / [ROUTER] overhead.
#   - Pair-programming with claude on someone else's machine without polluting workflow.
#   - Debugging whether a misbehavior comes from our hooks or upstream claude.
#
# What this touches:
#   - ~/.claude/settings.json  →  the `hooks` section only
#
# What this does NOT touch:
#   - ~/.claude/rules/         →  rule files stay loaded as memory
#   - ~/.claude/hooks/         →  hook script files stay on disk
#   - PostToolUse:Bash bg logger (jq writer to /tmp/claude-bg.log) — preserved
#
# Usage:
#   bash switch_hooks.sh off       # disable v2 hooks
#   bash switch_hooks.sh on        # re-enable v2 hooks
#   bash switch_hooks.sh status    # show current state
#
# Re-run is safe; both directions are idempotent.

set -euo pipefail

ACTION="${1:-status}"
SETTINGS="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
    echo "[switch] $SETTINGS not found — has set_claude.sh been run?" >&2
    exit 1
fi

# Hooks owned by barry-workflow v2 (deployed by set_claude.sh).
# Identified by leaf basename match on the registered command path.
BW_HOOK_BASENAMES=(
    inject_router.sh
    session_boot.sh
    pretooluse_short_nudge.sh
    state_enforce.sh
)

case "$ACTION" in
    off|disable)
        python3 - "$SETTINGS" "${BW_HOOK_BASENAMES[@]}" << 'PYEOF'
import json, os, sys
path = sys.argv[1]
basenames = set(sys.argv[2:])
with open(path) as f:
    cfg = json.load(f)
hooks = cfg.get("hooks", {})
removed = []
for event in list(hooks.keys()):
    new_bucket = []
    for grp in hooks[event]:
        kept = []
        for h in grp.get("hooks", []):
            cmd = h.get("command", "")
            if any(b in cmd for b in basenames):
                removed.append(f"{event} → {os.path.basename(cmd.split()[-1]) if cmd else cmd}")
            else:
                kept.append(h)
        if kept:
            entry = {"hooks": kept}
            if "matcher" in grp:
                entry["matcher"] = grp["matcher"]
            new_bucket.append(entry)
    if new_bucket:
        hooks[event] = new_bucket
    else:
        del hooks[event]
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
if removed:
    print("[switch] barry-workflow hooks DISABLED. Removed:")
    for r in removed:
        print(f"  - {r}")
else:
    print("[switch] no barry-workflow hooks were registered — nothing to disable.")
PYEOF
        ;;

    on|enable)
        python3 - "$SETTINGS" << 'PYEOF'
import json, os, sys
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
hooks = cfg.setdefault("hooks", {})

def ensure(event, matcher, command):
    bucket = hooks.setdefault(event, [])
    for grp in bucket:
        if matcher and grp.get("matcher") != matcher:
            continue
        if not matcher and grp.get("matcher"):
            continue
        for h in grp.get("hooks", []):
            if h.get("command", "") == command:
                return False
    entry = {"hooks": [{"type": "command", "command": command}]}
    if matcher:
        entry["matcher"] = matcher
    bucket.append(entry)
    return True

H = os.path.expanduser
added = []
for event, matcher, name in [
    ("UserPromptSubmit", None, "inject_router.sh"),
    ("UserPromptSubmit", None, "session_boot.sh"),
    ("PreToolUse",       None, "pretooluse_short_nudge.sh"),
    ("PostToolUse",      None, "state_enforce.sh"),
]:
    cmd = f"bash {H('~/.claude/hooks/')}{name}"
    if ensure(event, matcher, cmd):
        added.append(f"{event} → {name}")

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
if added:
    print("[switch] barry-workflow hooks ENABLED. Added:")
    for a in added:
        print(f"  - {a}")
else:
    print("[switch] all barry-workflow hooks already registered — nothing to add.")
PYEOF
        ;;

    status)
        python3 - "$SETTINGS" "${BW_HOOK_BASENAMES[@]}" << 'PYEOF'
import json, sys
path = sys.argv[1]
basenames = set(sys.argv[2:])
with open(path) as f:
    cfg = json.load(f)
hooks = cfg.get("hooks", {})
active = []
for event, bucket in hooks.items():
    for grp in bucket:
        for h in grp.get("hooks", []):
            cmd = h.get("command", "")
            for b in basenames:
                if b in cmd:
                    active.append(f"{event} → {b}")
total = len(basenames)
print(f"[switch] barry-workflow hooks: {len(active)}/{total} active")
for a in active:
    print(f"  ✓ {a}")
inactive = sorted(basenames - {a.split(' → ')[1] for a in active})
for b in inactive:
    print(f"  ✗ {b}")
PYEOF
        ;;

    *)
        echo "usage: bash switch_hooks.sh {on|off|status}" >&2
        exit 2
        ;;
esac
