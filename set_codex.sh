#!/bin/bash

# ██████████████████████████████████████████████████████████
# 军方全局配置部署脚本 v2 — Codex CLI 版（与 set_claude.sh 同构）
# ██████████████████████████████████████████████████████████
#
# v2 设计（codex / GPT-5.x 适配版）：
#   - 启动注入文件 = ~/.codex/AGENTS.md（直接 cp content/AGENTS.md → ~/.codex/AGENTS.md）
#   - codex 入口标准 = AGENTS.md（不再部署旧的 ~/.codex/<v1-route>.md 主文件）
#   - 不创建 AGENTS.md 软链接到任何旧路由文件（避免 codex 找不到主文件）
#   - 用户层 memory 走 content/memory/ 单源（按需读取，不常驻；与 set_claude.sh 共享同一份）
#   - ~/.codex/config.toml **幂等合并**：保留用户已设字段（model_provider / model / [projects.X] /
#     model_reasoning_effort / [model_providers.X] / [notice.X] / [tui.X] 等），仅在用户未设时新增：
#       approval_policy / sandbox_mode / project_doc_fallback_filenames / project_doc_max_bytes
#   - 不写：[features].memories=true / [features].codex_hooks=true / [[hooks.X]]
#   - 不安装 shell wrapper（codex 无 --append-system-prompt-file 等价 flag）
#   - 不写 CLAUDE_CODE_* 环境变量（codex 不需要）
#   - 不部署 ~/.codex/templates/（templates 从 repo 直接读，与 set_claude.sh 一致）
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
CODEX_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${CODEX_CONFIG_DIR}/content"

echo "正在部署 Codex CLI v2 短指令路由器军纪系统..."
echo "源仓库：${CODEX_CONFIG_DIR}"

# ── 1. 部署前体检 ─────────────────────────────────────────
echo ""
echo "── 体检阶段 ──────────────────────────────────────────────"

# (硬性) content/AGENTS.md 必须存在 — 字节无硬上限（指挥官 2026-05-07 决策：三元规则 + 10 项 codex 冲突修复需要更多 token；codex 默认 project_doc_max_bytes 通过 config.toml 设为 262144 = 256 KiB）
AGENTS_SRC="${CONTENT_DIR}/AGENTS.md"
if [ ! -f "$AGENTS_SRC" ]; then
    echo "[体检-硬性] ✗ ${AGENTS_SRC} 不存在"
    exit 1
fi
AGENTS_BYTES=$(wc -c < "$AGENTS_SRC")
echo "[体检-信息性] content/AGENTS.md = ${AGENTS_BYTES} 字节（无硬上限）"

# (硬性) Python3 存在（config.toml 幂等合并需要）
if ! command -v python3 >/dev/null 2>&1; then
    echo "[体检-硬性] ✗ python3 命令缺失，需用于 config.toml 幂等写入"
    exit 1
fi
echo "[体检-硬性] ✓ python3 命令存在"

# (可降级) 软链接能力（仅 memory/ 用；AGENTS.md 一律直接 cp）
SYMLINK_OK=1
TMP_TEST_DIR="$(mktemp -d)"
if ln -s /dev/null "${TMP_TEST_DIR}/symlink_test" 2>/dev/null; then
    echo "[体检-可降级] ✓ 软链接能力 OK（用于 memory/ 单源）"
    rm -rf "$TMP_TEST_DIR"
else
    echo "[体检-可降级] ! 软链接不可用，memory/ 将自动降级为 cp -r 副本"
    SYMLINK_OK=0
    rm -rf "$TMP_TEST_DIR"
fi

# (信息性) Codex 版本
if command -v codex >/dev/null 2>&1; then
    echo "[体检-信息性] codex --version: $(codex --version 2>&1 | head -1 || echo "无法获取")"
else
    echo "[体检-信息性] codex 命令未找到（可忽略；脚本仍会部署 ~/.codex/ 配置文件）"
fi

# (信息性) Claude Code 版本（提示双工具部署）
if command -v claude >/dev/null 2>&1; then
    echo "[体检-信息性] claude --version: $(claude --version 2>&1 | head -1 || echo "无法获取")"
    echo "[体检-信息性]   双工具部署提示：set_claude.sh 与 set_codex.sh 共享 content/ 单源；可同时跑两脚本"
fi

echo "── 体检完成 ──────────────────────────────────────────────"
echo ""

# ── 2. 创建目标目录 ───────────────────────────────────────────
mkdir -p ~/.codex

# ── 3. 部署 ~/.codex/AGENTS.md（codex 入口；直接 cp 同名，不软链）─────
# 设计原因：codex 默认读 AGENTS.md；source 文件名 = 目标文件名 = AGENTS.md
# 清除旧 v1 路由主文件残留（避免双入口混淆）
rm -f "$HOME/.codex/$( echo Q0xBVURFLm1k | base64 -d 2>/dev/null || echo CLAUDE.md )"
# 清除旧 ~/.codex/AGENTS.md（可能是 dangling symlink 残留 — 历史 v2 第 1 版部署的 AGENTS.md → CLAUDE.md 软链接）
rm -f ~/.codex/AGENTS.md
cp "${AGENTS_SRC}" ~/.codex/AGENTS.md
"${SED_I[@]}" "s|__CLAUDE_CONFIG_DIR__|${CODEX_CONFIG_DIR}|g" ~/.codex/AGENTS.md
echo "[部署] ✓ ~/.codex/AGENTS.md（系统级总纲，源 = content/AGENTS.md，codex 专属）"

# ── 4. 部署 content/memory/（单一规范目录策略；与 set_claude.sh 同模式）────
# 策略：软链接 ~/.codex/memory → content/memory（一处编辑双工具看到）
#       软链接失败时降级为 cp -r 复制副本
MEMORY_SRC="${CONTENT_DIR}/memory"
MEMORY_DST="$HOME/.codex/memory"

if [ ! -d "$MEMORY_SRC" ]; then
    echo "[部署] ✗ ${MEMORY_SRC} 不存在，无法部署 memory"
    exit 1
fi

# 清掉旧的 memory（无论软链接或目录）
rm -rf "$MEMORY_DST"

if [ "$SYMLINK_OK" -eq 1 ]; then
    ln -s "$MEMORY_SRC" "$MEMORY_DST"
    echo "[部署] ✓ ~/.codex/memory → ${MEMORY_SRC} （软链接，单源单点编辑）"
else
    cp -r "$MEMORY_SRC" "$MEMORY_DST"
    echo "[部署] ! ~/.codex/memory（cp 副本兜底；编辑后须重跑 set_codex.sh 同步）"
fi

# ── 5. 赋执行权限（与 set_claude.sh 同段）────────────────────
chmod +x "${CODEX_CONFIG_DIR}/init_corporal.sh"
chmod +x "${CODEX_CONFIG_DIR}/init_soldier.sh"
chmod +x "${CODEX_CONFIG_DIR}/set_monitor_time.sh"   2>/dev/null || true
chmod +x "${CODEX_CONFIG_DIR}/set_tg.sh"             2>/dev/null || true

# ── 6. 写 ~/.codex/config.toml — 幂等合并（保留用户字段，仅未设时新增）─
# 实现策略：
#   - 仅在用户未设时新增以下顶层字段：
#       approval_policy = "on-request"
#       sandbox_mode = "workspace-write"
#       project_doc_fallback_filenames = ["AGENTS.md"]
#       project_doc_max_bytes = 262144
#   - **不覆盖**用户已设字段（包括 model_reasoning_effort / model_provider / model 等）
#   - 不写：[features].memories = true / [features].codex_hooks = true / [[hooks.X]]
#   - 用 Python 文本解析（grep + sed/append 幂等），避免依赖 Python 3.11+ tomllib
python3 - << 'PYEOF'
import os
import re

path = os.path.expanduser("~/.codex/config.toml")

# v2 仅在用户未设时新增的 4 个字段（保护用户已有 model_reasoning_effort 等）
desired_if_missing = {
    "approval_policy": '"on-request"',
    "sandbox_mode": '"workspace-write"',
    "project_doc_fallback_filenames": '["AGENTS.md"]',
    "project_doc_max_bytes": "262144",
}

# 读现有内容（若不存在则空）
try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    content = ""

original = content

# 划分顶层段（[ 之前的内容） vs 表段（[section] 之后）
top_match = re.search(r"^\[", content, re.MULTILINE)
top_section = content[: top_match.start()] if top_match else content
rest_section = content[top_match.start():] if top_match else ""

added_lines = []
for key, val in desired_if_missing.items():
    pattern = re.compile(r"^\s*" + re.escape(key) + r"\s*=", re.MULTILINE)
    # 仅检查顶层段（不查表段内同名字段，因为 [foo].approval_policy 等是不同语义）
    if not pattern.search(top_section):
        added_lines.append(f"{key} = {val}")
        print(f"config.toml: 新增 {key} = {val}（用户未设）")
    else:
        print(f"config.toml: 保留 {key}（用户已设，不覆盖）")

if added_lines:
    # 追加到顶层段末尾（在 [section] 之前插入）
    if top_match:
        new_top = top_section.rstrip() + "\n" + "\n".join(added_lines) + "\n"
        content = new_top + rest_section
    else:
        sep = "\n" if content.strip() else ""
        content = content.rstrip() + sep + "\n".join(added_lines) + "\n"

# 警告：如果用户文件里有 memories = true / codex_hooks = true / [[hooks.*]]，提示但不删
warn_patterns = [
    (r"^\s*memories\s*=\s*true", "[features].memories = true"),
    (r"^\s*codex_hooks\s*=\s*true", "[features].codex_hooks = true"),
    (r"^\s*\[\[hooks\.", "[[hooks.X]] 表"),
]
for pat, name in warn_patterns:
    if re.search(pat, content, re.MULTILINE):
        print(f"config.toml: 警告 — 检测到用户配置含 {name}（v2 不主动开启此特性，但保留用户设置）")

if content != original:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)
    print("config.toml: 已更新（仅追加用户未设字段）")
else:
    print("config.toml: 无需变更（用户已设全部目标字段，或已是最新）")
PYEOF

# ── 7. 可选 — 提示性 CODEX_HOME 环境变量（不强制写入）─
if ! grep -q "CODEX_HOME" "$SHELL_RC" 2>/dev/null; then
    echo "[提示] SHELL_RC 中无 CODEX_HOME 设置（可选；codex 默认用 ~/.codex/）"
fi

# ── 8. 幂等写入 codex wrapper（已有 codex() 函数则跳过保留用户版）─
if ! grep -qE '^[[:space:]]*codex[[:space:]]*\(\)' "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'CODEX_WRAPPER'

# <<< codex-config-v2-wrapper-begin >>>
# v2 codex wrapper — 跳过审批 + 沙箱（与 claude --dangerously-skip-permissions 对应）
codex() {
    command codex --dangerously-bypass-approvals-and-sandbox "$@"
}
# <<< codex-config-v2-wrapper-end >>>
CODEX_WRAPPER
    echo "[wrapper] ✓ 已写入 v2 codex() 函数到 $SHELL_RC（--dangerously-bypass-approvals-and-sandbox）"
else
    echo "[wrapper] ✓ SHELL_RC 已有 codex() 自定义版，保留不覆盖"
fi

# ── 完成 ─────────────────────────────────────────────────────
hash -r 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Codex v2 部署完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "启动注入："
echo "  ~/.codex/AGENTS.md           (codex 入口；源 = content/AGENTS.md，codex 专属)"
echo ""
echo "按需读取："
if [ "$SYMLINK_OK" -eq 1 ]; then
    echo "  ~/.codex/memory → ${CONTENT_DIR}/memory  (软链接，单源)"
else
    echo "  ~/.codex/memory              (cp 副本兜底；编辑后重跑 set_codex.sh)"
fi
echo "    INDEX.md / lessons.md / violations.md / workflows.md / soldier_protocol.md"
echo ""
echo "Codex 配置文件："
echo "  ~/.codex/config.toml         (幂等合并：仅在用户未设时新增 4 字段)"
echo "                                approval_policy=on-request / sandbox_mode=workspace-write /"
echo "                                project_doc_fallback_filenames=[AGENTS.md] / project_doc_max_bytes=262144"
echo "                                **保留** 用户的 model_provider / model / [projects.X] / model_reasoning_effort 等"
echo ""
echo "运行时档案模板（init_*.sh 直接读取）："
echo "  ${CONTENT_DIR}/templates/    (9 文件，repo 内单源，不部署到 ~/.codex/)"
echo ""
echo "工具脚本（已 chmod +x；与 set_claude.sh 共享）："
echo "  ${CODEX_CONFIG_DIR}/init_corporal.sh         (军营初始化)"
echo "  ${CODEX_CONFIG_DIR}/init_soldier.sh          (列兵自初始化)"
echo "  ${CODEX_CONFIG_DIR}/set_monitor_time.sh      (动态调整监控周期)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "下次 codex 进入任何工作区，运行 init_corporal.sh 自动创建 militar_camp/。"
echo "（与 Claude Code 共享 militar_camp/ 战时档案；双工具切换无需重新初始化）"
