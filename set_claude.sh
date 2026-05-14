#!/bin/bash

# ██████████████████████████████████████████████████████████
# Military global config deployment script v2 — short-instruction router architecture
# ██████████████████████████████████████████████████████████
#
# v1.1 changes:
#   - Startup injection file has no hard byte limit (user explicitly said "no matter the cost")
#   - User-layer memory uses content/memory/ single source (on-demand Read, not resident)
#   - Repeated prompt reinforcement (recite policies + four-module reflection + 5-min monitor + facts-first + 4-step opening)
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

# (Hard) content/CLAUDE.md must exist — no hard byte limit (user decision 2026-05-07: three meta-rules reinforcement needs more tokens, removed 8192 hard cap)
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
echo "[cleanup] ✓ ~/.claude/system_override.txt deleted (no longer used in v2)"
# NOTE v2-hook: ~/.claude/rules/ is NOW USED in v2-hook (global auto-loaded rules dir).
# Old v1 rules/ was different concept. We keep this dir in v2 — see Step 5b for population.

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

# ── 5b. Deploy ~/.claude/rules/ (v2-hook NEW: global auto-loaded violation.md + lessons.md) ──
RULES_SRC="${CONTENT_DIR}/templates/global_rules"
RULES_DST="$HOME/.claude/rules"

if [ ! -d "$RULES_SRC" ]; then
    echo "[deploy] ✗ ${RULES_SRC} does not exist, cannot deploy global rules"
    exit 1
fi

mkdir -p "$RULES_DST"

for f in violation.md lessons.md; do
    src="${RULES_SRC}/${f}"
    dst="${RULES_DST}/${f}"
    if [ ! -f "$src" ]; then
        echo "[deploy] ⚠ source missing: ${src} (skipping)"
        continue
    fi
    if [ -f "$dst" ]; then
        # Conflict handling per v2-plan: warn + ASK user, do nothing by default
        if ! cmp -s "$src" "$dst"; then
            echo ""
            echo "[deploy] ⚠ CONFLICT: ${dst} already exists and differs from source."
            echo "          Source: $src"
            echo "          Target: $dst"
            echo "          Differences (first 20 lines):"
            diff "$src" "$dst" 2>/dev/null | head -20 | sed 's/^/            /'
            echo ""
            read -r -p "          Overwrite ${dst}? [y/N]: " ans </dev/tty || ans="N"
            case "$ans" in
                y|Y|yes|YES)
                    cp "$src" "$dst"
                    echo "[deploy] ✓ ${dst} overwritten"
                    ;;
                *)
                    echo "[deploy] - ${dst} kept as-is (skipped overwrite)"
                    ;;
            esac
        else
            echo "[deploy] ✓ ${dst} already up to date"
        fi
    else
        cp "$src" "$dst"
        echo "[deploy] ✓ ${dst} deployed (new)"
    fi
done

# ── 5b'. Deploy v4 policy files (content/rules/ → ~/.claude/rules/) ──
V4_RULES_SRC="${CONTENT_DIR}/rules"
if [ -d "$V4_RULES_SRC" ]; then
    for f in p1_identity.md p2_facts_first.md p3_dispatch.md p4_recording.md p6_workflow.md subagent_rules.md fsm.md index.md; do
        src="${V4_RULES_SRC}/${f}"
        dst="${RULES_DST}/${f}"
        if [ ! -f "$src" ]; then
            echo "[deploy] ⚠ v4 rule source missing: ${src} (skipping)"
            continue
        fi
        cp "$src" "$dst"
        echo "[deploy] ✓ ${dst} (v4 policy)"
    done
else
    echo "[deploy] ⚠ ${V4_RULES_SRC} missing — v4 rules not deployed"
fi

# ── 5c. Deploy ~/.claude/hooks/ (legacy inject_decrees*.sh kept on disk; v4 P2: inject_router.sh) ──
HOOKS_SRC="${CLAUDE_CONFIG_DIR}/hooks"
HOOKS_DST="$HOME/.claude/hooks"

if [ ! -d "$HOOKS_SRC" ]; then
    echo "[deploy] ✗ ${HOOKS_SRC} does not exist, cannot deploy hooks"
    exit 1
fi

mkdir -p "$HOOKS_DST"

for f in inject_decrees.sh inject_decrees_to_subagent.sh stop_self_audit.sh reset_session_status.sh inject_router.sh; do
    src="${HOOKS_SRC}/${f}"
    dst="${HOOKS_DST}/${f}"
    if [ ! -f "$src" ]; then
        echo "[deploy] ⚠ hook source missing: ${src} (skipping)"
        continue
    fi
    # v2-hook: cp + sed substitute __CLAUDE_CONFIG_DIR__ → actual repo path.
    # MUST `rm -f $dst` first: previous deployments may have left a symlink at $dst
    # pointing to $src; `cp $src $dst` then fails with "same file" error.
    # Also sed -i on a symlink would modify the source file in repo — DANGEROUS.
    rm -f "$dst"
    cp "$src" "$dst"
    "${SED_I[@]}" "s|__CLAUDE_CONFIG_DIR__|${CLAUDE_CONFIG_DIR}|g" "$dst"
    chmod +x "$dst"
    echo "[deploy] ✓ ${dst} (cp + sed-substitute __CLAUDE_CONFIG_DIR__)"
done

chmod +x "${HOOKS_SRC}"/*.sh 2>/dev/null || true

# Smoke-test hooks
if bash -n "${HOOKS_SRC}/inject_decrees.sh" 2>&1 && bash -n "${HOOKS_SRC}/inject_decrees_to_subagent.sh" 2>&1; then
    echo "[deploy] ✓ hooks syntax check passed"
else
    echo "[deploy] ⚠ hooks syntax check failed — review hook scripts"
fi

INJECT_BYTES=$(bash "${HOOKS_SRC}/inject_decrees.sh" 2>/dev/null | wc -c)
echo "[deploy] [INFO] inject_decrees.sh output = ${INJECT_BYTES} bytes (Claude Code hook cap = 10000)"
if [ "$INJECT_BYTES" -ge 10000 ]; then
    echo "[deploy] ⚠ inject_decrees.sh output >= 10000 bytes — Claude Code will truncate. Slim the script."
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
# v4 P1: do not force effortLevel (user-controlled).
# if cfg.get("effortLevel") != "high":
#     cfg["effortLevel"] = "high"
#     changed = True

hooks = cfg.setdefault("hooks", {})

# ── v2-hook NEW: register UserPromptSubmit, PostToolUse:Agent, PreToolUse:Agent, Stop ──
INJECT_SCRIPT = os.path.expanduser("~/.claude/hooks/inject_decrees.sh")
INJECT_SUBAGENT_SCRIPT = os.path.expanduser("~/.claude/hooks/inject_decrees_to_subagent.sh")
STOP_AUDIT_SCRIPT = os.path.expanduser("~/.claude/hooks/stop_self_audit.sh")

def ensure_hook(event, matcher, command):
    """Idempotent: add (event, matcher, command) hook entry if not present."""
    global changed
    bucket = hooks.setdefault(event, [])
    # Check for existing entry with same command
    for grp in bucket:
        if matcher and grp.get("matcher") != matcher:
            continue
        if not matcher and grp.get("matcher"):
            continue
        for h in grp.get("hooks", []):
            if h.get("command", "") == command:
                return  # already present
    entry = {"hooks": [{"type": "command", "command": command}]}
    if matcher:
        entry["matcher"] = matcher
    bucket.append(entry)
    changed = True

# v4 P2: slim router hook replaces the four legacy v2-hook registrations.
# Legacy scripts (inject_decrees.sh / inject_decrees_to_subagent.sh /
# reset_session_status.sh / stop_self_audit.sh) remain on disk for reference
# but are no longer auto-registered.
ROUTER_SCRIPT = os.path.expanduser("~/.claude/hooks/inject_router.sh")
ensure_hook("UserPromptSubmit", None, f"bash {ROUTER_SCRIPT}")

# ── v2 preserved: PostToolUse=Bash background logger (debug use, unrelated to memory) ──
BG_HOOK_CMD = (
    "jq -c 'select(.tool_input.run_in_background==true) | "
    "{ts: now, id: .tool_use_id, resp: .tool_response, cmd: .tool_input.command}' "
    ">> /tmp/claude-bg.log"
)
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
    print("settings.json: updated (v2-hook registrations)")
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
echo "    INDEX.md / workflows.md / soldier_protocol.md (+ deprecated violations.md / lessons.md)"
echo ""
echo "Auto-loaded global rules (v2-hook NEW):"
echo "  ~/.claude/rules/violation.md     (cross-project AI rule violations)"
echo "  ~/.claude/rules/lessons.md       (cross-project AI behavior wisdom)"
echo ""
echo "Hooks (v2-hook — cp + sed-substituted, NOT symlinked):"
echo "  ~/.claude/hooks/inject_decrees.sh                (cp+sed; re-run set_claude.sh after edits)"
echo "  ~/.claude/hooks/inject_decrees_to_subagent.sh    (cp+sed)"
echo "  ~/.claude/hooks/stop_self_audit.sh               (cp+sed)"
echo "  ~/.claude/hooks/reset_session_status.sh          (cp+sed)"
echo "  Registered in ~/.claude/settings.json:"
echo "    UserPromptSubmit  → inject_decrees.sh   (user msg + cron tick)"
echo "    PostToolUse:Agent → inject_decrees.sh   (re-inject after subagent returns)"
echo "    PreToolUse:Agent  → inject_decrees_to_subagent.sh (inject into subagent prompt)"
echo "    Stop              → stop_self_audit.sh (blocks 1st stop, prompts self-audit; 2nd stop allowed)"
echo ""
echo "Runtime archive templates (read directly by init_*.sh):"
echo "  ${CONTENT_DIR}/templates/                  (project-level: operation_log/attempts_ledger/bitter_lessons/successful_fixes + corporal_X/* + soldier_X/*)"
echo "  ${CONTENT_DIR}/templates/global_rules/     (source for ~/.claude/rules/)"
echo ""
echo "Utility scripts (chmod +x applied):"
echo "  ${CLAUDE_CONFIG_DIR}/init_corporal.sh         (workspace init — to be renamed in P3)"
echo "  ${CLAUDE_CONFIG_DIR}/init_soldier.sh          (subagent self-init — to be renamed in P3)"
echo "  ${CLAUDE_CONFIG_DIR}/set_monitor_time.sh      (Dynamic monitoring interval adjustment)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next time you enter any workspace, Claude runs init_corporal.sh to auto-create militar_camp/ (legacy — P3 will replace with BOOT hook → .barry_workflow/)."
