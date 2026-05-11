#!/bin/bash

# ██████████████████████████████████████████████████████████
# 军方全局配置部署脚本 v2 — 短指令路由器架构
# ██████████████████████████████████████████████████████████
#
# v1.1 改动：
#   - 启动注入文件无硬字节上限（指挥官明示「不计代价」）
#   - 用户层 memory 走 content/memory/ 单源（按需 Read，不常驻）
#   - 暴力重复 prompt 加强（朗读 + 反思四模块 + 监控 5 分钟 + 事实优先 + 4 步开局）
#   - 监控周期可由 set_monitor_time.sh 动态调整
#   - skill 体系（如 censor）按 README ## 4 手动 ln -sfn 部署
#
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

echo "正在部署 Claude v2 短指令路由器军纪系统..."
echo "源仓库：${CLAUDE_CONFIG_DIR}"

# ── 1. 部署前体检（plan ## 5.3 三类）──────────────────────────
echo ""
echo "── 体检阶段 ──────────────────────────────────────────────"

# (硬性) ln 命令存在
if ! command -v ln >/dev/null 2>&1; then
    echo "[体检-硬性] ✗ ln 命令缺失，请先安装 coreutils"
    exit 1
fi
echo "[体检-硬性] ✓ ln 命令存在"

# (硬性) content/CLAUDE.md 必须存在 — 字节无硬上限（指挥官 2026-05-07 决策：三元规则强化需要更多 token，去掉 8192 硬卡）
CLAUDE_V2_SRC="${CONTENT_DIR}/CLAUDE.md"
if [ ! -f "$CLAUDE_V2_SRC" ]; then
    echo "[体检-硬性] ✗ ${CLAUDE_V2_SRC} 不存在"
    exit 1
fi
CLAUDE_V2_BYTES=$(wc -c < "$CLAUDE_V2_SRC")
echo "[体检-信息性] CLAUDE.md = ${CLAUDE_V2_BYTES} 字节（无硬上限）"

# (可降级) 软链接能力
SYMLINK_OK=1
TMP_TEST_DIR="$(mktemp -d)"
if ln -s /dev/null "${TMP_TEST_DIR}/symlink_test" 2>/dev/null; then
    echo "[体检-可降级] ✓ 软链接能力 OK"
    rm -rf "$TMP_TEST_DIR"
else
    echo "[体检-可降级] ! 软链接不可用，将自动降级为复制副本"
    SYMLINK_OK=0
    rm -rf "$TMP_TEST_DIR"
fi

# (信息性) Claude 版本
if command -v claude >/dev/null 2>&1; then
    echo "[体检-信息性] claude --version: $(claude --version 2>&1 | head -1 || echo "无法获取")"
    echo "[体检-信息性]   建议升级到 v2.1.59+ 以启用机制层 auto memory；本 v2 用户层方案不依赖该版本"
else
    echo "[体检-信息性] claude 命令未找到（可忽略，仅影响信息性提示）"
fi

# (信息性) Codex memories experimental
if command -v codex >/dev/null 2>&1; then
    CODEX_MEM_LINE=$(codex features list 2>&1 | grep -i memories || echo "（未获取到 memories 行）")
    echo "[体检-信息性] codex memories: ${CODEX_MEM_LINE}"
    echo "[体检-信息性]   EU/UK/CH 启动期 features.memories 不可用；本 v2 不依赖此特性"
else
    echo "[体检-信息性] codex 命令未找到（可忽略，仅影响信息性提示）"
fi

echo "── 体检完成 ──────────────────────────────────────────────"
echo ""

# ── 2. 创建目标目录 ───────────────────────────────────────────
mkdir -p ~/.claude

# ── 3. 清理 v1 副作用（防止 ~/.claude/ 残留 v1 死代码）─────────
echo "── 清理 v1 残留 ──────────────────────────────────────────"
rm -f ~/.claude/system_override.txt
rm -rf ~/.claude/rules
echo "[清理] ✓ ~/.claude/system_override.txt 已删（v2 不再使用）"
echo "[清理] ✓ ~/.claude/rules/ 已删（v2 用 content/memory/ + content/templates/ 替代）"

# ── 4. 部署 CLAUDE.md（源 = content/CLAUDE.md）────────────
cp "${CLAUDE_V2_SRC}" ~/.claude/CLAUDE.md
"${SED_I[@]}" "s|__CLAUDE_CONFIG_DIR__|${CLAUDE_CONFIG_DIR}|g" ~/.claude/CLAUDE.md
cp ~/.claude/CLAUDE.md ~/CLAUDE.md
echo "[部署] ✓ ~/.claude/CLAUDE.md（系统级总纲，源 = content/CLAUDE.md）"
echo "[部署] ✓ ~/CLAUDE.md（home 工作区版本，与系统级一致 — 双重保障）"

# ── 5. 部署 content/memory/（单一规范目录策略）────────────────
# 策略：软链接 ~/.claude/memory → content/memory（一处编辑双工具看到）
#       软链接失败时降级为 cp -r 复制副本
MEMORY_SRC="${CONTENT_DIR}/memory"
MEMORY_DST="$HOME/.claude/memory"

if [ ! -d "$MEMORY_SRC" ]; then
    echo "[部署] ✗ ${MEMORY_SRC} 不存在，无法部署 memory"
    exit 1
fi

# 清掉旧的 memory（无论软链接或目录）
rm -rf "$MEMORY_DST"

if [ "$SYMLINK_OK" -eq 1 ]; then
    ln -s "$MEMORY_SRC" "$MEMORY_DST"
    echo "[部署] ✓ ~/.claude/memory → ${MEMORY_SRC} （软链接，单源单点编辑）"
else
    cp -r "$MEMORY_SRC" "$MEMORY_DST"
    echo "[部署] ! ~/.claude/memory（cp 副本兜底；编辑后须重跑 set_claude.sh 同步）"
fi

# ── 6. 赋执行权限（脚本已在 repo 中，直接 chmod）────────────
chmod +x "${CLAUDE_CONFIG_DIR}/init_corporal.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/init_soldier.sh"
chmod +x "${CLAUDE_CONFIG_DIR}/set_monitor_time.sh"   2>/dev/null || true
chmod +x "${CLAUDE_CONFIG_DIR}/set_tg.sh"             2>/dev/null || true

# ── 7. 清理 v1 shell wrapper（v2 不再需要 wrapper）────────────
"${SED_I[@]}" '/^# <<< claude-config-begin >>>/,/^# <<< claude-config-end >>>/d' "$SHELL_RC"
rm -f ~/.local/bin/claude 2>/dev/null || true

# 宽容清理 — 即使 begin/end 标记被用户手动删过，也清掉 v1 wrapper 残留行
# （v2 不再需要 --append-system-prompt-file 或 system_override.txt 引用）
if grep -qE 'append-system-prompt-file|system_override\.txt' "$SHELL_RC" 2>/dev/null; then
    cp "$SHELL_RC" "$SHELL_RC.v1.bak.$(date +%s)"
    "${SED_I[@]}" '/append-system-prompt-file/d' "$SHELL_RC"
    "${SED_I[@]}" '/system_override\.txt/d' "$SHELL_RC"
    echo "[清理] ✓ SHELL_RC 中 v1 wrapper 残留行已删（含 --append-system-prompt-file / system_override.txt 引用；备份在 $SHELL_RC.v1.bak.*）"
    echo "[清理] ⚠ 如残留孤立的 'claude() {' 或 '}' 注释行，请手动 sed 清理"
else
    echo "[清理] ✓ SHELL_RC 无 v1 wrapper 残留"
fi

# 幂等写入 v2 claude wrapper（已有 claude() 函数则跳过保留用户版）
if ! grep -qE '^[[:space:]]*claude[[:space:]]*\(\)' "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'CLAUDE_WRAPPER'

# <<< claude-config-v2-wrapper-begin >>>
# v2 简化 wrapper — 跳过权限提示；不再用 --append-system-prompt-file（v2 不需要 system_override.txt）
claude() {
    command claude --dangerously-skip-permissions "$@"
}
# <<< claude-config-v2-wrapper-end >>>
CLAUDE_WRAPPER
    echo "[wrapper] ✓ 已写入 v2 claude() 函数到 $SHELL_RC（--dangerously-skip-permissions）"
else
    echo "[wrapper] ✓ SHELL_RC 已有 claude() 自定义版，保留不覆盖"
fi

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

# ── 9. 写 ~/.claude/settings.json — 幂等合并（保留 v1 调试 logger）─
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

# v2 保留：PostToolUse=Bash background logger（调试用，与 memory 无关）
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

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " v2 部署完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "启动注入："
echo "  ~/.claude/CLAUDE.md          (系统级总纲，源 = content/CLAUDE.md)"
echo "  ~/CLAUDE.md                  (双重保障，与系统级一致)"
echo ""
echo "按需 Read："
if [ "$SYMLINK_OK" -eq 1 ]; then
    echo "  ~/.claude/memory → ${CONTENT_DIR}/memory  (软链接，单源)"
else
    echo "  ~/.claude/memory             (cp 副本兜底；编辑后重跑 set_claude.sh)"
fi
echo "    INDEX.md / lessons.md / violations.md / workflows.md / soldier_protocol.md"
echo ""
echo "运行时档案模板（init_*.sh 直接读取）："
echo "  ${CONTENT_DIR}/templates/    (9 文件，repo 内单源，不部署到 ~/.claude/)"
echo ""
echo "工具脚本（已 chmod +x）："
echo "  ${CLAUDE_CONFIG_DIR}/init_corporal.sh         (军营初始化)"
echo "  ${CLAUDE_CONFIG_DIR}/init_soldier.sh          (列兵自初始化)"
echo "  ${CLAUDE_CONFIG_DIR}/set_monitor_time.sh      (动态调整监控周期)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "下次进入任何工作区，Claude 运行 init_corporal.sh 自动创建 militar_camp/。"
