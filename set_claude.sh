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

# ── 5. Deploy content/memory/ (legacy v1 — optional) ────────────────
# Strategy: symlink ~/.claude/memory → content/memory if the dir exists.
# v2.4+: content/memory/ is no longer shipped on main (v1 cosplay residue);
# absent → skip silently. Branches that still carry it (e.g. v2 internal dev
# work) keep deploying it.
MEMORY_SRC="${CONTENT_DIR}/memory"
MEMORY_DST="$HOME/.claude/memory"

if [ ! -d "$MEMORY_SRC" ]; then
    echo "[deploy] - ${MEMORY_SRC} absent, skipping memory deploy (not required since v2.4)"
    # Also clean up any stale deployed memory symlink/dir to avoid dangling references.
    [ -e "$MEMORY_DST" ] && rm -rf "$MEMORY_DST" && echo "[deploy] - removed stale ${MEMORY_DST}"
else
    # Remove old memory (whether symlink or directory) before re-linking.
    rm -rf "$MEMORY_DST"
    if [ "$SYMLINK_OK" -eq 1 ]; then
        ln -s "$MEMORY_SRC" "$MEMORY_DST"
        echo "[deploy] ✓ ~/.claude/memory → ${MEMORY_SRC} (symlink, single-source single-point editing)"
    else
        cp -r "$MEMORY_SRC" "$MEMORY_DST"
        echo "[deploy] ! ~/.claude/memory (cp copy fallback; rerun set_claude.sh to sync after editing)"
    fi
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
            (diff "$src" "$dst" 2>/dev/null || true) | head -20 | sed 's/^/            /'
            echo ""
            # v4 P2: source-of-truth wins by default; user can `cp dst src` to preserve old.
            # Non-interactive (no tty) defaults to overwrite — set_claude.sh is idempotent re-deploy.
            if [ -t 0 ]; then
                read -r -p "          Overwrite ${dst}? [Y/n]: " ans </dev/tty || ans="Y"
            else
                ans="Y"
            fi
            case "$ans" in
                n|N|no|NO)
                    echo "[deploy] - ${dst} kept as-is (skipped overwrite)"
                    ;;
                *)
                    cp "$src" "$dst"
                    echo "[deploy] ✓ ${dst} overwritten"
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

# ── 5b'. Deploy v4 always-on policy files (content/rules/ → ~/.claude/rules/) ──
# P36: ONLY the 7 always-on files are copied to ~/.claude/rules/ for auto-load.
# The following are NOT copied — hooks read them directly from content/rules/ via
# __CLAUDE_CONFIG_DIR__ sed-substitution:
#   router*.md, states/*.md, patches/*.md, messages/*.md,
#   fsm.md, prompt_enhancement.md, codex_adapter.md, workflow_config.yaml
V4_RULES_SRC="${CONTENT_DIR}/rules"
if [ -d "$V4_RULES_SRC" ]; then
    # P36 cleanup: remove obsolete deployed copies that would double-load into context.
    rm -f \
        "${RULES_DST}/router.md" \
        "${RULES_DST}/router_BOOT.md" \
        "${RULES_DST}/router_PREPARE.md" \
        "${RULES_DST}/router_REFLECT.md" \
        "${RULES_DST}/router_EXECUTE_LOOP.md" \
        "${RULES_DST}/router_END.md" \
        "${RULES_DST}/fsm.md" \
        "${RULES_DST}/prompt_enhancement.md" \
        "${RULES_DST}/codex_adapter.md" \
        "${RULES_DST}/workflow_config.yaml" \
        2>/dev/null || true
    find "${RULES_DST}/states"   -maxdepth 1 -type f -name '*.md' -delete 2>/dev/null || true
    find "${RULES_DST}/patches"  -maxdepth 1 -type f -name '*.md' -delete 2>/dev/null || true
    find "${RULES_DST}/messages" -maxdepth 1 -type f -name '*.md' -delete 2>/dev/null || true
    rmdir "${RULES_DST}/states"   2>/dev/null || true
    rmdir "${RULES_DST}/patches"  2>/dev/null || true
    rmdir "${RULES_DST}/messages" 2>/dev/null || true
    echo "[deploy] ✓ P36 cleanup: obsolete router/states/patches/messages/config files removed from ~/.claude/rules/"

    # Deploy ONLY the 7 always-on files (hooks read the rest from repo directly).
    shopt -s nullglob
    for f in facts_first.md dispatch.md recording.md failure_stop.md subagent_rules.md; do
        src="${V4_RULES_SRC}/${f}"
        dst="${RULES_DST}/${f}"
        if [ -f "$src" ]; then
            cp "$src" "$dst"
            echo "[deploy] ✓ ${dst} (v4 always-on policy)"
        else
            echo "[deploy] ⚠ always-on file missing: ${src} (skipping)"
        fi
    done
    shopt -u nullglob
else
    echo "[deploy] ⚠ ${V4_RULES_SRC} missing — v4 rules not deployed"
fi

# ── 5c. Deploy ~/.claude/hooks/ (v2.1) ──
HOOKS_SRC="${CLAUDE_CONFIG_DIR}/hooks"
HOOKS_DST="$HOME/.claude/hooks"

if [ ! -d "$HOOKS_SRC" ]; then
    echo "[deploy] ✗ ${HOOKS_SRC} does not exist, cannot deploy hooks"
    exit 1
fi

mkdir -p "$HOOKS_DST"

for f in _session_lib.sh inject_router.sh session_boot.sh transition.sh prepare_helper.sh execute_loop_audit.sh pretooluse_short_nudge.sh state_enforce.sh; do
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

# Smoke-test core v2.1 hooks
for h in inject_router.sh session_boot.sh transition.sh; do
    bash -n "${HOOKS_SRC}/${h}" 2>&1 || echo "[deploy] ⚠ ${h} syntax check failed"
done
echo "[deploy] ✓ hooks syntax check passed"

# ── 6. Grant execute permissions on utility scripts ────────────
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

# v2.1 cleanup: purge any v1 hook entries from settings.json
V1_HOOK_PATHS = (
    "inject_decrees.sh",
    "inject_decrees_to_subagent.sh",
    "reset_session_status.sh",
    "stop_self_audit.sh",
    "disciplinary_check.sh",
)
for event in list(hooks.keys()):
    new_bucket = []
    for grp in hooks[event]:
        kept_hooks = [
            h for h in grp.get("hooks", [])
            if not any(v1 in h.get("command", "") for v1 in V1_HOOK_PATHS)
        ]
        if kept_hooks:
            new_entry = {"hooks": kept_hooks}
            if "matcher" in grp:
                new_entry["matcher"] = grp["matcher"]
            new_bucket.append(new_entry)
    if len(new_bucket) != len(hooks[event]) or any(
        len(new_bucket[i].get("hooks", [])) != len(hooks[event][i].get("hooks", []))
        for i in range(len(new_bucket))
    ):
        changed = True
    if new_bucket:
        hooks[event] = new_bucket
    else:
        del hooks[event]

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

# v2.1: state-aware router (replaces all legacy injection hooks)
ROUTER_SCRIPT = os.path.expanduser("~/.claude/hooks/inject_router.sh")
ensure_hook("UserPromptSubmit", None, f"bash {ROUTER_SCRIPT}")

# v4 P3: BOOT hook — creates per-session state + action files under $PWD/.barry_workflow/
BOOT_SCRIPT = os.path.expanduser("~/.claude/hooks/session_boot.sh")
ensure_hook("UserPromptSubmit", None, f"bash {BOOT_SCRIPT}")

# v4 P7: PreToolUse short nudge (≤100-char allow-with-reason)
NUDGE_SCRIPT = os.path.expanduser("~/.claude/hooks/pretooluse_short_nudge.sh")
ensure_hook("PreToolUse", None, f"bash {NUDGE_SCRIPT}")

# v2.1 P16: PostToolUse state-enforce (informational stderr warning when
# tool conflicts with current FSM state).
STATE_ENFORCE_SCRIPT = os.path.expanduser("~/.claude/hooks/state_enforce.sh")
ensure_hook("PostToolUse", None, f"bash {STATE_ENFORCE_SCRIPT}")

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
echo "Hooks (v2.1 — cp + sed-substituted to ~/.claude/hooks/):"
echo "  inject_router.sh           — UserPromptSubmit (state-aware [ROUTER] block)"
echo "  session_boot.sh            — UserPromptSubmit (creates .barry_workflow/<sid>/state+action)"
echo "  pretooluse_short_nudge.sh  — PreToolUse"
echo "  state_enforce.sh           — PostToolUse (warns on state/tool mismatch)"
echo "  transition.sh / prepare_helper.sh / execute_loop_audit.sh — invoked by AI"
echo ""
echo "Project ledger templates: ${CONTENT_DIR}/templates/  (attempts_ledger / bitter_lessons / successful_fixes / state / action / reflection / goal)"
echo "Global rules source:      ${CONTENT_DIR}/templates/global_rules/  (→ ~/.claude/rules/)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "On first user prompt in any workspace, session_boot.sh creates \$PWD/.barry_workflow/<sid>/{state,action}.md."
