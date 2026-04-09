[🇺🇸 English](README.md)

# claude-config

个人 Claude Code 配置。克隆本仓库，执行两条命令，即可在新机器上完整恢复工作环境。

## 文件说明

| 文件 | 用途 |
|---|---|
| `set_claude.sh` | 写入 CLAUDE.md、所有规则文件、system_override.txt，并在 `.bashrc` 中注入 `claude()` 包装函数 |
| `settings.json` | 插件配置 — 按第 3 步复制到 `~/.claude/settings.json` |
| `skills/gen-draft/` | 自定义全局 Skill：生成高层草稿，含依赖感知执行顺序与可观测输出 |
| `skills/gen-report/` | 自定义全局 Skill：简洁实验报告 |
| `skills/gen-report-detailed/` | 自定义全局 Skill：完整 13 节详细报告 |
| `skills/experiment-run/` | 自定义全局 Skill：配置驱动的实验提交，含结构化输出与记录 |
| `skills/claude-config-sync/` | 自定义全局 Skill：同步本仓库 |
| `skills/paper-reader/` + 7 个子 skill | **论文 / 长文阅读套件**：编排 `pdf-ingest`、`contrib-extract`、`pipeline-walk`、`math-explain`、`old-vs-new`、`zero-jump-check`、`concise-complete`,以逐块、动机优先、零逻辑跳跃的方式讲解论文 |
| `ten_commandments_for_ai_coding.zh.md` | [📖 AI 辅助编程十戒](ten_commandments_for_ai_coding.zh.md) |

---

## 迁移到新机器

### 第 0 步 — 安装 Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

验证：`claude --version`

### 第 1 步 — 克隆仓库

```bash
git clone https://github.com/gyy0592/claude-config.git
cd claude-config
```

### 第 2 步 — 执行安装脚本

```bash
bash set_claude.sh
source ~/.bashrc
```

该脚本会写入：
- `~/.claude/CLAUDE.md` — 全局指令
- `~/.claude/rules/` — 3 个规则文件（artifacts、执行环境、调试/自主性）
- `~/.claude/system_override.txt` — 每次 `claude` 调用时自动注入的系统提示
- 在 `~/.bashrc` 中注入 `claude()` 包装函数，自动插入系统提示

### 第 3 步 — 安装插件

插件安装分 **三个子步骤**，需在 Claude Code 内部执行（均为斜杠命令，非终端命令）：

```bash
# 第 3a 步 — 复制配置（在终端执行）
cp settings.json ~/.claude/settings.json

# 第 3b 步 — 添加插件市场（在 Claude Code 内执行）
/plugin marketplace add anthropics/skills
/plugin marketplace add humania-org/humanize
/plugin marketplace add openai/codex-plugin-cc

# 第 3c 步 — 安装插件（在 Claude Code 内执行）
/plugin install humanize@humania
/plugin install document-skills@anthropic-agent-skills
/plugin install claude-api@anthropic-agent-skills
/plugin install codex@openai-codex
```

> **为什么要按此顺序？** `settings.json` 中的 `extraKnownMarketplaces` 启用插件发现，但若未先执行 `/plugin marketplace add`，`/plugin install` 会失败。

| 插件 | 技能 |
|---|---|
| `humanize@humania` | ask-codex, humanize, humanize-gen-plan, humanize-rlcr |
| `document-skills@anthropic-agent-skills` | pdf, docx, pptx, xlsx, frontend-design, canvas-design, algorithmic-art, brand-guidelines, doc-coauthoring, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing, claude-api |
| `claude-api@anthropic-agent-skills` | 同上 17 个技能，claude-api 变体 |
| `codex@openai-codex` | codex CLI 集成 |

### 第 4 步 — 安装自定义全局 Skills

```bash
mkdir -p ~/.claude/skills
# 软链接每个 skill，仓库内的修改即时生效
for s in skills/*/; do
  name=$(basename "$s")
  ln -sfn "$(pwd)/skills/$name" ~/.claude/skills/"$name"
done
```

| Skill | 触发方式 |
|---|---|
| `gen-draft` | `/gen-draft`、"write draft"、"generate draft" |
| `gen-report` | `/gen-report`、"write report"、"summarize experiment" |
| `gen-report-detailed` | `/gen-report-detailed`、"detailed report"、"full report" |
| `experiment-run` | `/experiment-run`、"run experiment"、"submit job" |
| `claude-config-sync` | `/claude-config-sync`、"sync config"、"push config" |
| `this-cluster` | 编写 Slurm 脚本、选择 Python 环境或设置 GPU 参数时自动参考 |
| `paper-reader` | `/read-paper`、`/paper-reader`、"读这篇论文"、"解析这篇文章" — 完整论文阅读流水线 |
| `pdf-ingest` | PDF 作为输入时自动调用(一次性提取文本 + 渲染页面图像) |
| `contrib-extract` | "这篇论文的贡献是什么"、"有什么创新"、`/contributions` — 四要素法则 |
| `pipeline-walk` | "逐步讲解这个方法"、"走一遍这个 pipeline"、`/walk` — 按论文顺序逐阶段走读 |
| `math-explain` | "用数学解释"、"推导一下"、"更严谨点" — 每个公式的必经之门 |
| `old-vs-new` | "对比 A 和 B"、"新方法比旧方法好在哪" — Before/After 结构化对比 |
| `zero-jump-check` | "这一步跳过了推导"、"填上中间步骤"、"审一下这个证明" — 步骤间逻辑审计 |
| `concise-complete` | "压缩一下"、"去掉废话"、"更密" — 最终语言打磨 pass |

---

## 保持仓库同步

```bash
cp ~/.claude/settings.json settings.json
# 将所有已跟踪的自定义 skill 从 ~/.claude/skills/ 同步回仓库
for s in skills/*/; do
  name=$(basename "$s")
  [ -d ~/.claude/skills/"$name" ] && rsync -a --delete ~/.claude/skills/"$name"/ skills/"$name"/
done
cp ~/set_claude.sh set_claude.sh
git add -A && git commit -m "sync" && git push
```

---

## 致谢

**AI 辅助编程十戒**（`ten_commandments_for_ai_coding.zh.md`）改编自 Dr. Sihao Liu 的 [Humanize](https://github.com/humania-org/humanize) 方法论，并加入了个人修改与补充。原始框架提供了 AI 辅助软件开发的结构化方法——本仓库版本融入了项目特定扩展（如：前置优先执行顺序、可观测输出追踪）。
