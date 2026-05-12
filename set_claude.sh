#!/bin/bash

# ██████████████████████████████████████████████████████████
# Military global config deployment script v2 — short-instruction router architecture
# ██████████████████████████████████████████████████████████
#
# v1.1 changes:
#   - Startup injection file has no hard byte limit (Commander explicitly said "no matter the cost")
#   - User-layer memory uses content/memory/ single source (on-demand Read, not resident)
#   - Forceful repetition prompt reinforcement (recite Decrees + four-module reflection + 5-min monitor + facts-first + 4-step opening)
#   - Monitoring interval can be dynamically adjusted by set_monitor_time.sh
#   - Skill system (e.g. censor) deployed manually via README ## 4 with ln -sfn
#
# To modify rule files, edit the corresponding files under content/, then rerun this script.

set -euo pipefail

# Cross-platform sed -i: macOS requires an explicit backup suffix, Linux does not.
if sed --version 2>/dev/null | grep -q GNU; then
    SED_I=(sed -i)
else
    SED_I=(sed -i '')
fi

# Detect user's shell rc file (macOS defaults to zsh since Catalina)
if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi
touch "$SHELL_RC"

# Detect the script's own directory (correct regardless of where it is run from)
CLAUDE_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${CLAUDE_CONFIG_DIR}/content"

echo "Deploying Claude v2 short-instruction router military discipline system..."
echo "Source repo: ${CLAUDE_CONFIG_DIR}"

# ── 1. Pre-deployment health check (plan ## 5.3 three types) ──────────────────────────
echo ""
echo "── Health check phase ──────────────────────────────────────────────"

# (Hard) ln command exists
if ! command -v ln >/dev/null 2>&1; then
    echo "[health-hard] ✗ ln command missing, please install coreutils first"
    exit 1
fi
echo "[health-hard] ✓ ln command exists"

# (Hard) content/CLAUDE.md must exist — no hard byte limit (Commander 2026-05-07 decision: three meta-rules reinforcement needs more tokens, removed 8192 hard cap)
CLAUDE_V2_SRC="${CONTENT_DIR}/CLAUDE.md"
if [ ! -f "$CLAUDE_V2_SRC" ]; then
    echo "[health-hard] ✗ ${CLAUDE_V2_SRC} does not exist"
    exit 1
fi
CLAUDE_V2_BYTES=$(wc -c < "$CLAUDE_V2_SRC")
echo "[health-info] CLAUDE.md = ${CLAUDE_V2_BYTES} bytes (no hard limit)"

# (Degradable) symlink capability
SYMLINK_OK=1
TMP_TEST_DIR="$(mktemp -d)"
if ln -s /dev/null "${TMP_TEST_DIR}/symlink_test" 2>/dev/null; then
    echo "[health-degradable] ✓ symlink capability OK"
    rm -rf "$TMP_TEST_DIR"
else
    echo "[health-degradable] ! symlinks unavailable, will automatically fall back to copy"
    SYMLINK_OK=0
    rm -rf "$TMP_TEST_DIR"
fi

# (Informational) Claude version
if command -v claude >/dev/null 2>&1; then
    echo "[health-info] claude --version: $(claude --version 2>&1 | head -1 || echo "unable to retrieve")"
    echo "[health-info]   Recommended: upgrade to v2.1.59+ to enable mechanism-layer auto memory; this v2 user-layer approach does not depend on that version"
else
    echo "[health-info] claude command not found (ignorable, only affects informational prompts)"
fi

# (Informational) Codex memories experimental
if command -v codex >/dev/null 2>&1; then
    CODEX_MEM_LINE=$(codex features list 2>&1 | grep -i memories || echo "(failed to retrieve memories line)")
    echo "[health-info] codex memories: ${CODEX_MEM_LINE}"
    echo "[health-info]   EU/UK/CH launch-period features.memories unavailable; this v2 does not depend on this feature"
else
    echo "[health-info] codex command not found (ignorable, only affects informational prompts)"
fi

echo "── Health check complete ──────────────────────────────────────────────"
echo ""

# ── 2. Create target directory ───────────────────────────────────────────
mkdir -p ~/.claude

# ── 3. Clean up v1 side-effects (prevent ~/.claude/ residual v1 dead code) ─────────
echo "── Cleaning up v1 residuals ──────────────────────────────────────────────"
rm -f ~/.claude/system_override.txt
rm -rf ~/.claude/rules
echo "[cleanup] ✓ ~/.claude/system_override.txt deleted (no longer used in v2)"
echo "[cleanup] ✓ ~/.claude/rules/ deleted (v2 uses content/memory/ + content/templates/ instead)"

# ── 4. Deploy CLAUDE.md (source = content/CLAUDE.md) ────────────
cp "${CLAUDE_V2_SRC}" ~/.claude/CLAUDE.md
"${SED_I[@]}" "s|__CLAUDE_CONFIG_DIR__|${CLAUDE_CONFIG_DIR}|g" ~/.claude/CLAUDE.md
cp ~/.claude/CLAUDE.md ~/CLAUDE.md
echo "[deploy] ✓ ~/.claude/CLAUDE.md (system-level master, source = content/CLAUDE.md)"
echo "[deploy] ✓ ~/CLAUDE.md (home workspace version, identical to system-level — dual guarantee)"

# ── 5. Deploy content/memory/ (single canonical directory strategy) ────────────────
# Strategy: symlink ~/.claude/memory → content/memory (edit in one place, both tools see it)
#           fall back to cp -r copy if symlink fails
MEMORY_SRC="${CONTENT_DIR}/memory"
MEMORY_DST="$HOME/.claude/memory"

if [ ! -d "$MEMORY_SRC" ]; then
    echo "[deploy] ✗ ${MEMORY_SRC} does not exist, cannot deploy memory"
    exit 1
fi

# Remove old memory (whether symlink or directory)
rm -rf "$MEMORY_DST"

if [ "$SYMLINK_OK" -eq 1 ]; then
    ln -s "$MEMORY_SRC" "$MEMORY_DST"
    echo "[deploy] ✓ ~/.claude/memory → ${MEMORY_SRC} (symlink, single-source single-point editing)"
else
    cp -r "$MEMORY_SRC" "$MEMORY_DST"
    echo "[deploy] ! ~/.claude/memory (cp copy fallback; rerun set_claude.sh to sync after editing)"
fi

# ── 6. Grant execute permissions (scripts are already in repo, chmod directly) ────────────
chmod +x "${CLAUDE_CONFIG_DIR}/init_corporal.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/init_soldier.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/set_monitor_time.sh"   2>/dev/null || true
chmod +x "${CLAUDE_CONFIG_DIR}/set_tg.sh"             2>/dev/null || true

# ── 7. Clean up v1 shell wrapper (no longer needed in v2) ────────────
"${SED_I[@]}" '/^# <<< claude-config-begin >>>/,/^# <<< claude-config-end >>>/d' "$SHELL_RC"
rm -f ~/.local/bin/claude 2>/dev/null || true

# Graceful cleanup — remove v1 wrapper residual lines even if begin/end markers were manually deleted by user
# (v2 no longer needs --append-system-prompt-file or system_override.txt references)
if grep -qE 'append-system-prompt-file|system_override\.txt' "$SHELL_RC" 2>/dev/null; then
    cp "$SHELL_RC" "$SHELL_RC.v1.bak.$(date +%s)"
    "${SED_I[@]}" '/append-system-prompt-file/d' "$SHELL_RC"
    "${SED_I[@]}" '/system_override\.txt/d' "$SHELL_RC"
    echo "[cleanup] ✓ v1 wrapper residual lines removed from SHELL_RC (including --append-system-prompt-file / system_override.txt references; backup at $SHELL_RC.v1.bak.*)"
    echo "[cleanup] ⚠ If orphaned 'claude() {' or '}' comment lines remain, please clean manually with sed"
else
    echo "[cleanup] ✓ SHELL_RC has no v1 wrapper residuals"
fi

# Idempotent write of v2 claude wrapper (skip if claude() function already exists — preserve user version)
if ! grep -qE '^[[:space:]]*claude[[:space:]]*\(\)' "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'CLAUDE_WRAPPER'

# <<< claude-config-v2-wrapper-begin >>>
# v2 simplified wrapper — skip permission prompts; no longer uses --append-system-prompt-file (v2 does not need system_override.txt)
claude() {
    command claude --dangerously-skip-permissions "$@"
}
# <<< claude-config-v2-wrapper-end >>>
CLAUDE_WRAPPER
    echo "[wrapper] ✓ v2 claude() function written to $SHELL_RC (--dangerously-skip-permissions)"
else
    echo "[wrapper] ✓ SHELL_RC already has custom claude() version, preserved without overwrite"
fi

# ── 8. Add Humanize pipeline + performance tuning environment variables ─────────────
if ! grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" << 'ENVVARS'

# Humanize pipeline environment variables
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
export HUMANIZE_CODEX_BYPASS_SANDBOX=true
ENVVARS
fi

if ! grep -q "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" << 'THINKINGVARS'

# Claude Code — disable adaptive thinking, force full reasoning budget
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
THINKINGVARS
fi

# ── 9. Write ~/.claude/settings.json — idempotent merge (preserve v1 debug logger) ─
CLAUDE_CONFIG_DIR_FOR_PY="${CLAUDE_CONFIG_DIR}" python3 - << 'PYEOF'
import json, os

path = os.path.expanduser("~/.claude/settings.json")
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

changed = False

if cfg.get("showThinkingSummaries") is not True:
    cfg["showThinkingSummaries"] = True
    changed = True
if cfg.get("effortLevel") != "high":
    cfg["effortLevel"] = "high"
    changed = True

# v2 preserved: PostToolUse=Bash background logger (debug use, unrelated to memory)
BG_HOOK_CMD = (
    "jq -c 'select(.tool_input.run_in_background==true) | "
    "{ts: now, id: .tool_use_id, resp: .tool_response, cmd: .tool_input.command}' "
    ">> /tmp/claude-bg.log"
)
hooks = cfg.setdefault("hooks", {})
post_tool = hooks.setdefault("PostToolUse", [])
bg_hook_present = any(
    grp.get("matcher") == "Bash" and any(
        h.get("command", "").startswith(
            "jq -c 'select(.tool_input.run_in_background==true)"
        )
        for h in grp.get("hooks", [])
    )
    for grp in post_tool
)
if not bg_hook_present:
    post_tool.append({
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": BG_HOOK_CMD}],
    })
    changed = True

# Remove old Stop hook (idempotent cleanup)
if "Stop" in hooks:
    before = len(hooks["Stop"])
    hooks["Stop"] = [
        entry for entry in hooks["Stop"]
        if not any(
            "disciplinary_check.sh" in h.get("command", "")
            for h in ([entry] if "command" in entry else entry.get("hooks", []))
            if isinstance(h, dict)
        )
    ]
    if not hooks["Stop"]:
        del hooks["Stop"]
    if len(hooks.get("Stop", [])) != before:
        changed = True

if changed:
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print("settings.json: updated")
else:
    print("settings.json: already up to date")
PYEOF

# ── Done ─────────────────────────────────────────────────────
hash -r 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " v2 Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Startup injection:"
echo "  ~/.claude/CLAUDE.md          (system-level master, source = content/CLAUDE.md)"
echo "  ~/CLAUDE.md                  (dual guarantee, identical to system-level)"
echo ""
echo "On-demand Read:"
if [ "$SYMLINK_OK" -eq 1 ]; then
    echo "  ~/.claude/memory → ${CONTENT_DIR}/memory  (symlink, single source)"
else
    echo "  ~/.claude/memory             (cp copy fallback; rerun set_claude.sh after editing)"
fi
echo "    INDEX.md / lessons.md / violations.md / workflows.md / soldier_protocol.md"
echo ""
echo "Runtime archive templates (read directly by init_*.sh):"
echo "  ${CONTENT_DIR}/templates/    (9 files, single source in repo, not deployed to ~/.claude/)"
echo ""
echo "Utility scripts (chmod +x applied):"
echo "  ${CLAUDE_CONFIG_DIR}/init_corporal.sh         (Military camp init)"
echo "  ${CLAUDE_CONFIG_DIR}/init_soldier.sh          (Private self-init)"
echo "  ${CLAUDE_CONFIG_DIR}/set_monitor_time.sh      (Dynamic monitoring interval adjustment)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next time you enter any workspace, Claude runs init_corporal.sh to auto-create militar_camp/."
