#!/bin/bash
# ██████████████████████████████████████████████████████████
# make_release.sh — 打包 set_claude.sh / set_codex.sh 部署所需最小文件集
# ██████████████████████████████████████████████████████████
#
# 用法：bash make_release.sh
# 输出：/tmp/claude-config-v1.0.tar.gz
#
# 包含（v2 部署所需最小集）：
#   - set_claude.sh / set_codex.sh
#   - init_corporal.sh / init_soldier.sh
#   - content/CLAUDE.md / content/AGENTS.md
#   - content/memory/ 5 文件
#   - content/templates/ 9 文件（含 v1.0 版本标记）
#
# 不包含（v2 不依赖）：
#   - militar_camp/（运行时档案；gitignored）
#   - v1 残余工具脚本（disciplinary_check.sh 等；set_*.sh chmod 已 || true 容错）
#   - artifacts/ patches/ logs/ 等临时目录
#   - draft / prd / 旧设计文档

set -euo pipefail

VERSION="v1.0"
RELEASE_NAME="claude-config-${VERSION}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/tmp/${RELEASE_NAME}"
TARBALL="/tmp/${RELEASE_NAME}.tar.gz"

echo "═══════════════════════════════════════════════════"
echo " 打包 claude-config ${VERSION} release"
echo " 源目录：${SRC_DIR}"
echo " 目标 tarball：${TARBALL}"
echo "═══════════════════════════════════════════════════"

# 清理旧 release
rm -rf "$DEST" "$TARBALL"
mkdir -p "$DEST/content"

# ── 1. 部署脚本（v2 核心 4 个）─────
cp "$SRC_DIR/set_claude.sh"     "$DEST/"
cp "$SRC_DIR/set_codex.sh"      "$DEST/"
cp "$SRC_DIR/init_corporal.sh"  "$DEST/"
cp "$SRC_DIR/init_soldier.sh"   "$DEST/"
echo "[release] ✓ 4 部署脚本（set_claude.sh / set_codex.sh / init_corporal.sh / init_soldier.sh）"

# ── 2. content 主路由 + memory + templates ─────
cp "$SRC_DIR/content/CLAUDE.md"   "$DEST/content/"
cp "$SRC_DIR/content/AGENTS.md"   "$DEST/content/"
cp -r "$SRC_DIR/content/memory"   "$DEST/content/"
cp -r "$SRC_DIR/content/templates" "$DEST/content/"
echo "[release] ✓ content/{CLAUDE.md, AGENTS.md, memory/, templates/}"

# ── 3. 可选 README ─────
[ -f "$SRC_DIR/README.md" ]    && cp "$SRC_DIR/README.md"    "$DEST/" && echo "[release] ✓ README.md"
[ -f "$SRC_DIR/README.zh.md" ] && cp "$SRC_DIR/README.zh.md" "$DEST/" && echo "[release] ✓ README.zh.md"

# ── 4. 安装说明 ─────
cat > "$DEST/INSTALL.md" << EOF
# claude-config ${VERSION} — 安装

## 部署 Claude Code
\`\`\`bash
cd $(basename "$DEST")
bash set_claude.sh
\`\`\`

## 部署 Codex CLI
\`\`\`bash
bash set_codex.sh
\`\`\`

## 验证
\`\`\`bash
wc -c ~/.claude/CLAUDE.md ~/.codex/AGENTS.md     # 应均 > 12 KB
ls ~/.claude/memory/ ~/.codex/memory/             # 各 5 文件
\`\`\`

## 进入新仓库时（每个工作仓库一次）
\`\`\`bash
cd <你的工作仓库>
bash <claude-config-path>/init_corporal.sh \$PWD   # 创建 militar_camp/
\`\`\`
EOF
echo "[release] ✓ INSTALL.md（简明安装说明）"

# ── 5. 版本标记 ─────
cat > "$DEST/VERSION" << EOF
claude-config ${VERSION}
打包时间：$(date -u +"%Y-%m-%d %H:%M:%S UTC")
源 commit：$(cd "$SRC_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "non-git")
EOF
echo "[release] ✓ VERSION 文件"

# ── 6. 打包 ─────
cd /tmp
tar czf "$TARBALL" "$RELEASE_NAME"
TARBALL_SIZE=$(du -h "$TARBALL" | cut -f1)
FILE_COUNT=$(find "$DEST" -type f | wc -l)
echo ""
echo "═══════════════════════════════════════════════════"
echo " 完成"
echo " Tarball：${TARBALL}（${TARBALL_SIZE}，含 ${FILE_COUNT} 文件）"
echo " 解压：cd /tmp && tar xzf ${RELEASE_NAME}.tar.gz"
echo "═══════════════════════════════════════════════════"

# 保留 tarball + 清理临时目录
rm -rf "$DEST"
