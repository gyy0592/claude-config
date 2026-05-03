#!/bin/bash

# ██████████████████████████████████████████████████████████
# 军方全局配置部署脚本 — 运行后所有项目自动接受军事化管理
# ██████████████████████████████████████████████████████████
#
# 文本内容已拆分到 content/ 目录，本脚本只负责部署（cp + sed + chmod）。
# 修改规则文件请直接编辑 content/ 下对应文件，然后重新运行本脚本。

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

# 检测脚本自身所在目录（无论从哪里运行都正确）
CLAUDE_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${CLAUDE_CONFIG_DIR}/content"

echo "正在部署 Claude 多层军纪控制系统..."

# ── 1. 创建目标目录 ───────────────────────────────────────────
mkdir -p ~/.claude/rules/templates

# ── 2. 部署 system_override.txt ──────────────────────────────
cp "${CONTENT_DIR}/system_override.txt" ~/.claude/system_override.txt

# ── 3. 部署 CLAUDE.md（替换占位符 + 同步到 ~/CLAUDE.md）──────
cp "${CONTENT_DIR}/CLAUDE.md" ~/.claude/CLAUDE.md
"${SED_I[@]}" "s|__CLAUDE_CONFIG_DIR__|${CLAUDE_CONFIG_DIR}|g" ~/.claude/CLAUDE.md
cp ~/.claude/CLAUDE.md ~/CLAUDE.md

# ── 4. 部署 rules/ 文件 ──────────────────────────────────────
cp "${CONTENT_DIR}/rules/1_artifacts_memory.md"     ~/.claude/rules/
cp "${CONTENT_DIR}/rules/2_execution_env.md"         ~/.claude/rules/
cp "${CONTENT_DIR}/rules/3_debug_autonomy.md"        ~/.claude/rules/
cp "${CONTENT_DIR}/rules/4_subagent_orchestration.md" ~/.claude/rules/
cp "${CONTENT_DIR}/rules/5_autonomous_execution.md"  ~/.claude/rules/
cp "${CONTENT_DIR}/rules/6_user_facing_questions.md" ~/.claude/rules/
cp "${CONTENT_DIR}/rules/7_crimes_penalties.md"      ~/.claude/rules/

# ── 5. 部署 templates/ 文件 ──────────────────────────────────
cp "${CONTENT_DIR}/rules/templates/warning_board.md"      ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/reward_board.md"        ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/traitor.md"             ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/README.md"              ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/corporal_status.md"     ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/corporal_action.md"     ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/corporal_situation.md"  ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/soldier_status.md"      ~/.claude/rules/templates/
cp "${CONTENT_DIR}/rules/templates/soldier_action.md"      ~/.claude/rules/templates/

# ── 6. 赋执行权限（脚本已在 repo 中，直接 chmod）────────────
chmod +x "${CLAUDE_CONFIG_DIR}/init_corporal.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/disciplinary_check.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/start-jw.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/stop-jw.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/jw-capture-session.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/set_tg.sh"

# ── 7. 安装 wrapper 为 shell 函数（不是文件，防 AI 删除）─────
rm -f ~/.local/bin/claude 2>/dev/null || true
"${SED_I[@]}" '/^# <<< claude-config-begin >>>/,/^# <<< claude-config-end >>>/d' "$SHELL_RC"
cat >> "$SHELL_RC" << 'BASHFUNC'
# <<< claude-config-begin >>>
# Claude wrapper（function，不是文件 — 防止 AI agent 用 rm 干掉）
claude() {
    command claude --dangerously-skip-permissions --append-system-prompt-file "$HOME/.claude/system_override.txt" "$@"
}
# <<< claude-config-end >>>
BASHFUNC

# ── 8. 添加 Humanize pipeline + 性能调优环境变量 ─────────────
if ! grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" << 'ENVVARS'

# Humanize pipeline 环境变量
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
export HUMANIZE_CODEX_BYPASS_SANDBOX=true
ENVVARS
fi

if ! grep -q "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" << 'THINKINGVARS'

# Claude Code — 关闭 adaptive thinking，强制满推理预算
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
THINKINGVARS
fi

# ── 9. 写 ~/.claude/settings.json — 幂等合并 ─────────────────
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

# 移除旧版 Stop hook（幂等清理）
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
    print("settings.json: 已更新")
else:
    print("settings.json: 已是最新")
PYEOF

# ── 完成 ─────────────────────────────────────────────────────
hash -r 2>/dev/null || true

echo "部署完成！"
echo "-----------------------------------"
echo "全局军纪文件已写入："
echo "  ~/.claude/CLAUDE.md          (系统级总纲)"
echo "  ~/CLAUDE.md                  (home 工作区版本，与系统级内容一致 — 双重保障)"
echo "  ~/.claude/system_override.txt (注入 prompt)"
echo "  ~/.claude/rules/1_artifacts_memory.md"
echo "  ~/.claude/rules/2_execution_env.md"
echo "  ~/.claude/rules/3_debug_autonomy.md"
echo "  ~/.claude/rules/4_subagent_orchestration.md"
echo "  ~/.claude/rules/5_autonomous_execution.md"
echo "  ~/.claude/rules/6_user_facing_questions.md"
echo "  ~/.claude/rules/templates/   (9 份模板)"
echo "-----------------------------------"
echo "Wrapper：shell 函数在 $SHELL_RC（不是文件）"
echo "which claude → 真实 nvm binary（未变）"
echo "-----------------------------------"
echo "  ${CLAUDE_CONFIG_DIR}/init_corporal.sh (军营初始化脚本)"
echo "  ${CLAUDE_CONFIG_DIR}/disciplinary_check.sh (纪委审查脚本，手动或 daemon 调用，--force 跳过时间门控)"
echo "  ${CLAUDE_CONFIG_DIR}/start-jw.sh          (启动纪委后台 daemon，报告: /tmp/claude_jw/report.md)"
echo "  ${CLAUDE_CONFIG_DIR}/stop-jw.sh           (停止纪委后台 daemon)"
echo "-----------------------------------"
echo "下次进入任何工作区，Claude 运行 init_corporal.sh 自动创建 militar_camp/ + 下士档案。"
