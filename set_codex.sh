#!/bin/bash

# ██████████████████████████████████████████████████████████
# 军方全局配置部署脚本 v2 — Codex CLI 版（与 set_claude.sh 同构）
# ██████████████████████████████████████████████████████████
#
# v2 设计：
#   - 启动注入文件 ≤ 8 KB（仅 ~/.codex/CLAUDE.md + AGENTS.md → CLAUDE.md 软链）
#   - 用户层 memory 走 content/memory/ 单源（按需 Read，不常驻；与 set_claude.sh 共享同一份）
#   - ~/.codex/config.toml 写 5 个 codex 字段（不写 hooks / memories=true）
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

# ── 1. 部署前体检（plan ## 5.3 三类）──────────────────────────
echo ""
echo "── 体检阶段 ──────────────────────────────────────────────"

# (硬性) ln 命令存在
if ! command -v ln >/dev/null 2>&1; then
    echo "[体检-硬性] ✗ ln 命令缺失，请先安装 coreutils"
    exit 1
fi
echo "[体检-硬性] ✓ ln 命令存在"

# (硬性) wc -c CLAUDE.md ≤ 8192 字节（plan ## 7 启动注入预算；与 set_claude.sh 共用同一文件）
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

# (硬性) Python3 存在（config.toml 幂等写入需要）
if ! command -v python3 >/dev/null 2>&1; then
    echo "[体检-硬性] ✗ python3 命令缺失，需用于 config.toml 幂等写入"
    exit 1
fi
echo "[体检-硬性] ✓ python3 命令存在"

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

# (信息性) Codex 版本
if command -v codex >/dev/null 2>&1; then
    echo "[体检-信息性] codex --version: $(codex --version 2>&1 | head -1 || echo "无法获取")"
else
    echo "[体检-信息性] codex 命令未找到（可忽略，仅影响信息性提示；脚本仍会部署 ~/.codex/ 配置文件）"
fi

# (信息性) Codex memories experimental（plan ## 5.3 信息性项）
if command -v codex >/dev/null 2>&1; then
    CODEX_MEM_LINE=$(codex features list 2>&1 | grep -i memories || echo "（未获取到 memories 行）")
    echo "[体检-信息性] codex memories: ${CODEX_MEM_LINE}"
    echo "[体检-信息性]   EU/UK/CH 启动期 features.memories 不可用；本 v2 不依赖此特性"
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

# ── 3. 部署 ~/.codex/CLAUDE.md（源 = content/CLAUDE.md，与 set_claude.sh 共用）─
cp "${CLAUDE_V2_SRC}" ~/.codex/CLAUDE.md
"${SED_I[@]}" "s|__CLAUDE_CONFIG_DIR__|${CODEX_CONFIG_DIR}|g" ~/.codex/CLAUDE.md
echo "[部署] ✓ ~/.codex/CLAUDE.md（系统级总纲，源 = content/CLAUDE.md，与 set_claude.sh 单源）"

# ── 4. 部署 ~/.codex/AGENTS.md → CLAUDE.md 软链接（plan ## 5.2）─
# 软链接：让 codex 读 AGENTS.md 时自动落到 CLAUDE.md（同一份内容）
# 软链接失败可降级：cp CLAUDE.md AGENTS.md（cp 副本兜底）
rm -f ~/.codex/AGENTS.md
if [ "$SYMLINK_OK" -eq 1 ]; then
    ln -sf ~/.codex/CLAUDE.md ~/.codex/AGENTS.md
    echo "[部署] ✓ ~/.codex/AGENTS.md → ~/.codex/CLAUDE.md（软链接，单源单点编辑）"
else
    cp ~/.codex/CLAUDE.md ~/.codex/AGENTS.md
    echo "[部署] ! ~/.codex/AGENTS.md（cp 副本兜底；编辑后须重跑 set_codex.sh 同步）"
fi

# ── 5. 部署 content/memory/（单一规范目录策略；与 set_claude.sh 同模式）────
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

# ── 6. 赋执行权限（脚本已在 repo 中，直接 chmod；与 set_claude.sh 同段）─
chmod +x "${CODEX_CONFIG_DIR}/init_corporal.sh"
chmod +x "${CODEX_CONFIG_DIR}/init_soldier.sh"
chmod +x "${CODEX_CONFIG_DIR}/disciplinary_check.sh" 2>/dev/null || true
chmod +x "${CODEX_CONFIG_DIR}/start-jw.sh"           2>/dev/null || true
chmod +x "${CODEX_CONFIG_DIR}/stop-jw.sh"            2>/dev/null || true
chmod +x "${CODEX_CONFIG_DIR}/jw-capture-session.sh" 2>/dev/null || true
chmod +x "${CODEX_CONFIG_DIR}/set_tg.sh"             2>/dev/null || true

# ── 7. 写 ~/.codex/config.toml — 幂等合并（5 个 codex 字段；不写 hooks / memories=true）─
# 实现策略（plan ## 5.2 + ## 5.3）：
#   - 写入 5 字段：model_reasoning_effort / approval_policy / sandbox_mode /
#                  project_doc_fallback_filenames / project_doc_max_bytes
#   - 不写：[features].memories = true / [features].codex_hooks = true / [[hooks.X]] 任何 hook 表
#   - 用 Python 文本解析（grep + sed/append 幂等），避免依赖 Python 3.11+ tomllib
python3 - << 'PYEOF'
import os
import re

path = os.path.expanduser("~/.codex/config.toml")

# v2 写入的 5 个顶层字段（plan ## 5.2 + ## 6 明示）
desired = {
    "model_reasoning_effort": '"high"',
    "approval_policy": '"on-request"',
    "sandbox_mode": '"workspace-write"',
    "project_doc_fallback_filenames": '["CLAUDE.md"]',
    "project_doc_max_bytes": "262144",
}

# 读现有内容（若不存在则空）
try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    content = ""

original = content
changed = False

# 逐字段处理：存在则替换，不存在则追加到顶层段
for key, val in desired.items():
    # 匹配「行首 key = ...」（顶层；忽略 [section] 内同名字段以避免误伤）
    # 简单实现：仅匹配文件顶层段（[ 之前的内容）
    top_match = re.search(r"^\[", content, re.MULTILINE)
    top_section = content[: top_match.start()] if top_match else content
    rest_section = content[top_match.start() :] if top_match else ""

    pattern = re.compile(r"^" + re.escape(key) + r"\s*=.*$", re.MULTILINE)
    if pattern.search(top_section):
        new_top = pattern.sub(f"{key} = {val}", top_section)
        if new_top != top_section:
            content = new_top + rest_section
            changed = True
    else:
        # 追加到顶层段末尾（若无 [section]，直接追加；否则在 [section] 前插入）
        if top_match:
            content = top_section.rstrip() + f"\n{key} = {val}\n" + rest_section
        else:
            content = (content.rstrip() + "\n" if content.strip() else "") + f"{key} = {val}\n"
        changed = True

# 警告：如果用户文件里有 memories = true / codex_hooks = true / [[hooks.*]]，提示但不删
warn_patterns = [
    (r"^\s*memories\s*=\s*true", "[features].memories = true"),
    (r"^\s*codex_hooks\s*=\s*true", "[features].codex_hooks = true"),
    (r"^\s*\[\[hooks\.", "[[hooks.X]] 表"),
]
for pat, name in warn_patterns:
    if re.search(pat, content, re.MULTILINE):
        print(f"config.toml: 警告 — 检测到用户配置含 {name}（v2 不主动开启此特性，但保留用户设置）")

if changed:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)
    print("config.toml: 已更新（5 字段幂等写入）")
else:
    print("config.toml: 已是最新")
PYEOF

# ── 8. 可选 — 提示性 CODEX_HOME 环境变量（不强制写入）─
# 与 set_claude.sh 第 8 段（CLAUDE_CODE_* 环境变量）对比：codex 不需要等价环境变量
# 仅在 SHELL_RC 没有 CODEX_HOME 时打印提示；不主动写入避免破坏用户已有配置
if ! grep -q "CODEX_HOME" "$SHELL_RC" 2>/dev/null; then
    echo "[提示] SHELL_RC 中无 CODEX_HOME 设置（可选；codex 默认用 ~/.codex/）"
fi

# ── 完成 ─────────────────────────────────────────────────────
hash -r 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Codex v2 部署完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "启动注入（≤ 8 KB）："
echo "  ~/.codex/CLAUDE.md           (系统级总纲，源 = content/CLAUDE.md，与 set_claude.sh 单源)"
echo "  ~/.codex/AGENTS.md           (软链接 → CLAUDE.md，让 codex 读它时落到同一份内容)"
echo ""
echo "按需 Read（磁盘语料 ≤ 50 KB）："
if [ "$SYMLINK_OK" -eq 1 ]; then
    echo "  ~/.codex/memory → ${CONTENT_DIR}/memory  (软链接，单源)"
else
    echo "  ~/.codex/memory              (cp 副本兜底；编辑后重跑 set_codex.sh)"
fi
echo "    INDEX.md / lessons.md / violations.md / workflows.md / soldier_protocol.md"
echo ""
echo "Codex 配置文件："
echo "  ~/.codex/config.toml         (5 字段：reasoning_effort=high / approval=on-request /"
echo "                                sandbox=workspace-write / project_doc_fallback=[CLAUDE.md] /"
echo "                                project_doc_max_bytes=262144)"
echo ""
echo "运行时档案模板（init_*.sh 直接读取）："
echo "  ${CONTENT_DIR}/templates/    (9 文件，repo 内单源，不部署到 ~/.codex/)"
echo ""
echo "工具脚本（已 chmod +x；与 set_claude.sh 共享）："
echo "  ${CODEX_CONFIG_DIR}/init_corporal.sh         (军营初始化)"
echo "  ${CODEX_CONFIG_DIR}/init_soldier.sh          (列兵自初始化)"
echo "  ${CODEX_CONFIG_DIR}/disciplinary_check.sh    (纪委审查，可手动或 daemon 调用)"
echo "  ${CODEX_CONFIG_DIR}/start-jw.sh / stop-jw.sh (纪委后台 daemon)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "下次 codex 进入任何工作区，运行 init_corporal.sh 自动创建 militar_camp/。"
echo "（与 Claude Code 共享 militar_camp/ 战时档案；双工具切换无需重新初始化）"
