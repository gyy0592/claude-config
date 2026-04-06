[🇺🇸 English](#-english) | [🇨🇳 中文](#-中文)

---

<a name="-english"></a>
# claude-config 🇺🇸

Personal Claude Code configuration. Clone this repo and run two commands to fully restore on a new machine.

## Contents

| File | Purpose |
|---|---|
| `set_claude.sh` | Writes CLAUDE.md, all rule files, system_override.txt, and patches `.bashrc` with the `claude()` wrapper |
| `settings.json` | Plugin config — copy to `~/.claude/settings.json` as part of Step 3 |
| `skills/gen-draft/` | Custom global skill: generate high-level draft with dependency-aware execution order and observable outputs |
| `skills/gen-report/` | Custom global skill: concise experiment report |
| `skills/gen-report-detailed/` | Custom global skill: full 13-section detailed report |
| `skills/experiment-run/` | Custom global skill: config-driven experiment submission with structured output and recording |
| `skills/claude-config-sync/` | Custom global skill: sync this repo |
| `ten_commandments_for_ai_coding.md` | Methodology guide for AI-assisted coding — [📖 Ten Commandments for AI Coding](ten_commandments_for_ai_coding.md) |

---

## Migration (new machine)

### Step 0 — Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Verify: `claude --version`

### Step 1 — Clone

```bash
git clone https://github.com/gyy0592/claude-config.git
cd claude-config
```

### Step 2 — Run setup script

```bash
bash set_claude.sh
source ~/.bashrc
```

This writes:
- `~/.claude/CLAUDE.md` — global instructions
- `~/.claude/rules/` — 3 rule files (artifacts, execution env, debug/autonomy)
- `~/.claude/system_override.txt` — system prompt injected on every `claude` call
- Patches `~/.bashrc` with `claude()` wrapper that auto-injects the system prompt

### Step 3 — Install plugins

Plugin installation is a **three-step process** that must happen inside Claude Code (all commands are slash commands, not terminal):

```bash
# Step 3a — Copy settings (run in terminal)
cp settings.json ~/.claude/settings.json

# Step 3b — Add marketplaces (run inside Claude Code)
/plugin marketplace add anthropics/skills
/plugin marketplace add humania-org/humanize
/plugin marketplace add openai/codex-plugin-cc

# Step 3c — Install plugins (run inside Claude Code)
/plugin install humanize@humania
/plugin install document-skills@anthropic-agent-skills
/plugin install claude-api@anthropic-agent-skills
/plugin install codex@openai-codex
```

> **Why this order?** `extraKnownMarketplaces` in `settings.json` enables discovery but `/plugin install` will fail unless `/plugin marketplace add` is run first.

| Plugin | Skills |
|---|---|
| `humanize@humania` | ask-codex, humanize, humanize-gen-plan, humanize-rlcr |
| `document-skills@anthropic-agent-skills` | pdf, docx, pptx, xlsx, frontend-design, canvas-design, algorithmic-art, brand-guidelines, doc-coauthoring, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing, claude-api |
| `claude-api@anthropic-agent-skills` | same 17 skills, claude-api variant |
| `codex@openai-codex` | codex CLI integration |

### Step 4 — Install custom global skills

```bash
mkdir -p ~/.claude/skills
# Symlink each skill so edits in the repo are reflected immediately
for s in skills/*/; do
  name=$(basename "$s")
  ln -sfn "$(pwd)/skills/$name" ~/.claude/skills/"$name"
done
```

| Skill | Trigger |
|---|---|
| `gen-draft` | `/gen-draft`, "write draft", "generate draft" |
| `gen-report` | `/gen-report`, "write report", "summarize experiment" |
| `gen-report-detailed` | `/gen-report-detailed`, "detailed report", "full report" |
| `experiment-run` | `/experiment-run`, "run experiment", "submit job" |
| `claude-config-sync` | `/claude-config-sync`, "sync config", "push config" |
| `this-cluster` | Auto-consulted when writing Slurm scripts, choosing Python envs, or setting GPU flags |

---

## Keeping this repo up to date

```bash
cp ~/.claude/settings.json settings.json
cp -r ~/.claude/skills/gen-report skills/gen-report
cp -r ~/.claude/skills/gen-report-detailed skills/gen-report-detailed
cp ~/set_claude.sh set_claude.sh
git add -A && git commit -m "sync" && git push
```

---

## Credits

**Ten Commandments for AI-Assisted Coding** (`ten_commandments_for_ai_coding.md`) is adapted from the methodology of [Humanize](https://github.com/humania-org/humanize) by Dr. Sihao Liu, with personal modifications and additions. The original framework provides a structured approach to AI-assisted software development — the version in this repo incorporates project-specific extensions (e.g., Prerequisite-First execution ordering, observable output tracking).

---
---

<a name="-中文"></a>
# claude-config 🇨🇳

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
| `ten_commandments_for_ai_coding.md` | AI 辅助编程方法论 — [📖 AI 辅助编程十戒](ten_commandments_for_ai_coding.md) |

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

---

## 保持仓库同步

```bash
cp ~/.claude/settings.json settings.json
cp -r ~/.claude/skills/gen-report skills/gen-report
cp -r ~/.claude/skills/gen-report-detailed skills/gen-report-detailed
cp ~/set_claude.sh set_claude.sh
git add -A && git commit -m "sync" && git push
```

---

## 致谢

**AI 辅助编程十戒**（`ten_commandments_for_ai_coding.md`）改编自 Dr. Sihao Liu 的 [Humanize](https://github.com/humania-org/humanize) 方法论，并加入了个人修改与补充。原始框架提供了 AI 辅助软件开发的结构化方法——本仓库版本融入了项目特定扩展（如：前置优先执行顺序、可观测输出追踪）。
