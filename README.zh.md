[🇺🇸 English](README.md)

# claude-config

个人 Claude Code 配置，含自动化开发流水线。克隆并执行即可在新机器上恢复。

---

## 快速开始

### 1. 安装依赖

```bash
npm install -g @anthropic-ai/claude-code
npm install -g @openai/codex
```

### 2. 克隆并配置

```bash
git clone https://github.com/gyy0592/claude-config.git
cd claude-config

# Claude Code：写入 CLAUDE.md、规则文件、system_override，并配置 shell rc
bash set_claude.sh && source "${ZDOTDIR:-$HOME}/.zshrc" 2>/dev/null || source ~/.bashrc

# Codex CLI：填入你的 base_url 和 api_key，然后运行配置
cp codex_info.yaml.template codex_info.yaml
# 编辑 codex_info.yaml → 填写 'now' 部分
bash setup_codex.sh
```

### 3. 安装插件（在 Claude Code 内执行）

```bash
cp settings.json ~/.claude/settings.json

# 以下为斜杠命令，在 Claude Code 内执行
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex

# humanize 插件安装见下方专门章节
```

#### Humanize 插件管理

**清理旧安装：**
```bash
# 在 Claude Code 内 - 移除旧的 humanize 安装
/plugin uninstall humanize@humania  # 如果存在
/plugin uninstall humanize@PolyArch  # 如果存在
/plugin marketplace remove humania   # 如果存在
```

**从本地 git 仓库安装：**
```bash
# 1. 克隆/更新你的 fork
git clone https://github.com/gyy0592/humanize.git ~/Programs/humanize
cd ~/Programs/humanize && git checkout claude-latest

# 2. 在 Claude Code 中安装
/plugin marketplace add ~/Programs/humanize
/plugin install humanize@PolyArch
/reload-plugins
```

**更新工作流：**
```bash
cd ~/Programs/humanize
git fetch upstream dev
git rebase upstream/dev  # 保持 Claude 功能 + 最新上游更新
git push origin claude-latest --force-with-lease
# 如需要可在 Claude Code 中重新安装
```

#### Anthropics 官方 Skills

```bash
# 注册 marketplace
/plugin marketplace add anthropics/skills

# 安装文档创作套件（Excel、Word、PowerPoint、PDF）
/plugin install document-skills@anthropic-agent-skills

# 安装示例/展示技能集（共 13 个：frontend-design、mcp-builder、skill-creator、canvas-design 等）
/plugin install example-skills@anthropic-agent-skills

# 安装 Claude API/SDK 文档技能
/plugin install claude-api@anthropic-agent-skills

/reload-plugins
```

**包含的 Skills：**

| 插件 | 斜杠命令 |
|---|---|
| `document-skills` | `/document-skills:xlsx`、`/document-skills:docx`、`/document-skills:pptx`、`/document-skills:pdf` |
| `example-skills` | `/example-skills:frontend-design`、`/example-skills:mcp-builder`、`/example-skills:skill-creator`、`/example-skills:canvas-design` 等 [共 13 个](https://github.com/anthropics/skills) |
| `claude-api` | `/claude-api:claude-api` — 使用 Anthropic SDK 构建 LLM 应用 |

### 4. 安装自定义 Skills

```bash
mkdir -p ~/.claude/skills
for s in skills/*/; do
  ln -sfn "$(pwd)/skills/$(basename "$s")" ~/.claude/skills/"$(basename "$s")"
done
```

完整 Skill 列表和触发方式见 [docs/skills.zh.md](docs/skills.zh.md)。

---

## 自动化开发工作流

核心功能：**Humanize 流水线** — Claude 写代码，Codex 迭代审查，闭环运行。

```
draft.md  →  gen-plan  →  plan.md  →  RLCR 循环  →  完成
```

### 第 1 步：写草稿

创建 `draft.md`，写清楚**做什么**和**为什么**。包含：

- **目标** — 功能/修复要实现什么
- **已知事实 / 约束** — 如 "GPU 显存 < 24GB"、"遵循 `experiment-run` 输出规范"、"Python 3.10+"
- **粗略验收标准**（gen-plan 会将其正式化）

```bash
/gen-draft
```

### 第 2 步：生成计划

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md
```

### 第 3 步：审阅计划

**不要跳过这一步。** 阅读计划，确认验收标准、任务分解、路径边界。如有意见，用 `CMT: ... ENDCMT` 标注后 refine：

```bash
/humanize:refine-plan --input docs/plan.md
```

反复审阅直到计划正确。RLCR 循环是放大器——错误的计划被完美执行，结果仍然是错的。

### 第 4 步：运行 RLCR 循环

```bash
/humanize:start-rlcr-loop docs/plan.md --codex-model gpt-5.3-codex --max 5
```

| 参数 | 用途 |
|---|---|
| `--codex-model` | 审查用的 Codex 模型（如 `gpt-5.3-codex`） |
| `--max N` | 最大迭代次数 |
| `--yolo` | 全自动：跳过测验 + Claude 回答 Codex 问题 |
| `--skip-quiz` | 仅跳过计划理解测验 |
| `--agent-teams` | Agent Teams 并行开发 |
| `--skip-impl` | 跳过实现，直接代码审查 |

**循环原理：** Claude 实现 → 写摘要 → Codex 审查 → 反馈循环直到 COMPLETE → `codex review` 检查代码质量 → 修复问题 → 完成。

### 一键工作流（计划 + 循环）

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md --auto-start-rlcr-if-converged
```

### 监控 / 取消

```bash
# 设置（一次性）
source ~/.claude/plugins/cache/humania/humanize/*/scripts/humanize.sh

# 另一个终端监控
humanize monitor rlcr

# 取消
/humanize:cancel-rlcr-loop
```

---

## 同步

```bash
cp ~/.claude/settings.json settings.json
for s in skills/*/; do
  name=$(basename "$s")
  [ -d ~/.claude/skills/"$name" ] && rsync -a --delete ~/.claude/skills/"$name"/ skills/"$name"/
done
git add -A && git commit -m "sync" && git push
```

---

## 致谢

**AI 辅助编程十戒**（[EN](ten_commandments_for_ai_coding.md) | [ZH](ten_commandments_for_ai_coding.zh.md)）——改编自 Dr. Sihao Liu 的 [Humanize](https://github.com/humania-org/humanize) 方法论，加入个人扩展。
