#!/bin/bash

# ██████████████████████████████████████████████████████████
# 军方全局配置部署脚本 v2 — 短指令路由器架构
# ██████████████████████████████████████████████████████████
#
# v2 改动：
#   - 启动注入文件 ≤ 8 KB（仅 ~/.claude/CLAUDE.md + ~/CLAUDE.md）
#   - 用户层 memory 走 content/memory/ 单源（按需 Read，不常驻）
#   - 删除 system_override.txt + rules/ 7 文件 + claude shell wrapper
#   - 新增体检（硬性 ln 检测 + 可降级软链接 + 信息性版本提示）
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

# (硬性) wc -c CLAUDE.md ≤ 8192 字节（plan ## 7 启动注入预算）
CLAUDE_V2_SRC="${CONTENT_DIR}/CLAUDE.md"
if [ ! -f "$CLAUDE_V2_SRC" ]; then
    echo "[体检-硬性] ✗ ${CLAUDE_V2_SRC} 不存在"
    exit 1
fi
CLAUDE_V2_BYTES=$(wc -c < "$CLAUDE_V2_SRC")
if [ "$CLAUDE_V2_BYTES" -gt 8192 ]; then
    echo "[体检-硬性] ✗ CLAUDE.md = ${CLAUDE_V2_BYTES} 字节，超 8192 限制"
    exit 1
fi
echo "[体检-硬性] ✓ CLAUDE.md = ${CLAUDE_V2_BYTES} 字节（≤ 8192）"

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
chmod +x "${CLAUDE_CONFIG_DIR}/disciplinary_check.sh" 2>/dev/null || true
chmod +x "${CLAUDE_CONFIG_DIR}/start-jw.sh"           2>/dev/null || true
chmod +x "${CLAUDE_CONFIG_DIR}/stop-jw.sh"            2>/dev/null || true
chmod +x "${CLAUDE_CONFIG_DIR}/jw-capture-session.sh" 2>/dev/null || true
chmod +x "${CLAUDE_CONFIG_DIR}/set_tg.sh"             2>/dev/null || true

# ── 7. 清理 v1 shell wrapper（v2 不再需要 wrapper）────────────
"${SED_I[@]}" '/^# <<< claude-config-begin >>>/,/^# <<< claude-config-end >>>/d' "$SHELL_RC"
rm -f ~/.local/bin/claude 2>/dev/null || true
echo "[清理] ✓ SHELL_RC 中 claude wrapper 段已删（v2 不需要 wrapper）"

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
echo "启动注入（≤ 8 KB）："
echo "  ~/.claude/CLAUDE.md          (系统级总纲，源 = content/CLAUDE.md)"
echo "  ~/CLAUDE.md                  (双重保障，与系统级一致)"
echo ""
echo "按需 Read（磁盘语料 ≤ 50 KB）："
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
echo "  ${CLAUDE_CONFIG_DIR}/disciplinary_check.sh    (纪委审查，可手动或 daemon 调用)"
echo "  ${CLAUDE_CONFIG_DIR}/start-jw.sh / stop-jw.sh (纪委后台 daemon)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "下次进入任何工作区，Claude 运行 init_corporal.sh 自动创建 militar_camp/。"
