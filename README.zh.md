[🇺🇸 English](README.md)

# claude-config

个人 Claude Code 配置。克隆本仓库，执行几条命令，即可在新机器上完整恢复工作环境。

## 文件说明

| 文件 | 用途 |
|---|---|
| `set_claude.sh` | 写入 CLAUDE.md、所有规则文件、system_override.txt，并在 `.bashrc` 中注入 `claude()` 包装函数和环境变量 |
| `settings.json` | 插件配置 — 按第 3 步复制到 `~/.claude/settings.json` |
| `setup_codex.sh` | Codex CLI 配置 — 设置 `~/.codex/config.toml` 和 `auth.json`，支持 API Key 轮换 |
| `codex_info.yaml.template` | Codex API 凭据模板（复制为 `codex_info.yaml` 后填入你的密钥） |
| `skills/gen-draft/` | 自定义全局 Skill：生成高层草稿，含依赖感知执行顺序与可观测输出 |
| `skills/gen-report/` | 自定义全局 Skill：简洁实验报告 |
| `skills/gen-report-detailed/` | 自定义全局 Skill：完整 13 节详细报告 |
| `skills/experiment-run/` | 自定义全局 Skill：配置驱动的实验提交，含结构化输出与记录 |
| `skills/claude-config-sync/` | 自定义全局 Skill：同步本仓库 |
| `skills/dep-trace-launcher/` | 自定义全局 Skill：递归依赖追踪交互式启动器 |
| `skills/recursive-dep-trace/` | 自定义全局 Skill：单入口递归第一性原理代码追踪 |
| `skills/recursive-dep-trace-parallel/` | 自定义全局 Skill：并行递归依赖追踪（多 worker 批处理） |
| `skills/paper-reader/` + 7 个子 skill | **论文 / 长文阅读套件**：编排 `pdf-ingest`、`contrib-extract`、`pipeline-walk`、`math-explain`、`old-vs-new`、`zero-jump-check`、`concise-complete`，以逐块、动机优先、零逻辑跳跃的方式讲解论文 |
| `ten_commandments_for_ai_coding.zh.md` | [AI 辅助编程十戒](ten_commandments_for_ai_coding.zh.md) |

---

## 迁移到新机器

### 第 0 步 — 安装 Claude Code 和 Codex CLI

```bash
# 安装 Claude Code
npm install -g @anthropic-ai/claude-code

# 安装 Codex CLI（Humanize 自动化流水线的必需依赖）
npm install -g @openai/codex
```

验证：`claude --version` 和 `codex --version`

### 第 1 步 — 克隆仓库

```bash
git clone https://github.com/gyy0592/claude-config.git
cd claude-config
```

### 第 2 步 — 执行安装脚本

```bash
# 2a — Claude Code 配置
bash set_claude.sh
source ~/.bashrc

# 2b — Codex CLI 配置（设置 API 端点和密钥）
cp codex_info.yaml.template codex_info.yaml
# 编辑 codex_info.yaml：在 'now' 部分填入你的 base_url 和 api_key
bash setup_codex.sh
```

`set_claude.sh` 会写入：
- `~/.claude/CLAUDE.md` — 全局指令
- `~/.claude/rules/` — 3 个规则文件（artifacts、执行环境、调试/自主性）
- `~/.claude/system_override.txt` — 每次 `claude` 调用时自动注入的系统提示
- 在 `~/.bashrc` 中注入 `claude()` 包装函数和环境变量：
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — 启用 Agent Teams 并行开发
  - `HUMANIZE_CODEX_BYPASS_SANDBOX=true` — 绕过 Codex 沙箱（HPC/容器环境无 landlock 时必需）

`setup_codex.sh` 会写入：
- `~/.codex/config.toml` — 模型提供商配置
- `~/.codex/auth.json` — API 密钥
- 自动轮换历史凭据（now → last1 → last2 → last3 → last4）

### 第 3 步 — 安装插件

插件安装分 **三个子步骤**，需在 Claude Code 内部执行（均为斜杠命令，非终端命令）：

```bash
# 第 3a 步 — 复制配置（在终端执行）
cp settings.json ~/.claude/settings.json

# 第 3b 步 — 添加插件市场（在 Claude Code 内执行）
/plugin marketplace add humania-org/humanize
/plugin marketplace add openai/codex-plugin-cc

# 第 3c 步 — 安装插件（在 Claude Code 内执行）
/plugin install humanize@humania
/plugin install codex@openai-codex
```

> **为什么要按此顺序？** `settings.json` 中的 `extraKnownMarketplaces` 启用插件发现，但若未先执行 `/plugin marketplace add`，`/plugin install` 会失败。

| 插件 | 技能 |
|---|---|
| `humanize@humania` | gen-plan, start-rlcr-loop, refine-plan, start-pr-loop, ask-codex |
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
| `codex-fix` | `codex review` 失败时自动参考：bwrap 沙箱错误、流断开 |
| `dep-trace-launcher` | `/dep-trace-launcher`、"trace dependencies" — 交互式启动器 |
| `recursive-dep-trace` | `/recursive-dep-trace` — 单入口递归代码追踪 |
| `recursive-dep-trace-parallel` | `/recursive-dep-trace-parallel` — 并行递归追踪（多 worker） |
| `paper-reader` | `/read-paper`、`/paper-reader`、"读这篇论文"、"解析这篇文章" — 完整论文阅读流水线 |
| `pdf-ingest` | PDF 作为输入时自动调用（一次性提取文本 + 渲染页面图像） |
| `contrib-extract` | "这篇论文的贡献是什么"、"有什么创新"、`/contributions` — 四要素法则 |
| `pipeline-walk` | "逐步讲解这个方法"、"走一遍这个 pipeline"、`/walk` — 按论文顺序逐阶段走读 |
| `math-explain` | "用数学解释"、"推导一下"、"更严谨点" — 每个公式的必经之门 |
| `old-vs-new` | "对比 A 和 B"、"新方法比旧方法好在哪" — Before/After 结构化对比 |
| `zero-jump-check` | "这一步跳过了推导"、"填上中间步骤"、"审一下这个证明" — 步骤间逻辑审计 |
| `concise-complete` | "压缩一下"、"去掉废话"、"更密" — 最终语言打磨 pass |

---

## 自动化开发工作流

本配置的核心自动化功能是 **Humanize 流水线**：一个闭环系统，Claude 实现代码，Codex 迭代审查，直到所有验收标准通过。完整工作流为：

```
draft.md → gen-plan → plan.md → RLCR 循环 → 完成
```

### 第 1 步：写草稿 (`/gen-draft`)

创建 `draft.md`，描述你要构建的**是什么**以及**为什么**。草稿应包含：

- **目标**：该功能/修复/重构应该实现什么
- **已知事实 / 约束**：规划器必须遵守的重要上下文。例如：
  - "如果出现 bwrap 沙箱错误，使用 `codex-fix` skill"
  - "输出目录结构遵循 `experiment-run` 规范"
  - "GPU 显存必须控制在 24GB 以内"
  - "必须兼容 Python 3.10+"
- **验收标准**（可选粗略版本 — gen-plan 会将其正式化）

```bash
/gen-draft
```

### 第 2 步：生成实施计划 (`/humanize:gen-plan`)

将草稿转化为包含验收标准、任务分解和路径边界的结构化计划。Claude 和 Codex 通过多轮收敛讨论来完善计划。

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md
```

审阅生成的计划。如有意见，用 `CMT: ... ENDCMT` 块标注后运行：

```bash
/humanize:refine-plan --input docs/plan.md
```

### 第 3 步：运行 RLCR 循环 (`/humanize:start-rlcr-loop`)

RLCR（Review-Loop-Code-Review）循环通过 Codex 迭代审查来自动化实施：

```bash
/humanize:start-rlcr-loop docs/plan.md --codex-model gpt-5.3-codex --max 5
```

**参数说明：**
- `docs/plan.md` — 计划文件路径
- `--codex-model gpt-5.3-codex` — 用于审查的 Codex 模型
- `--max 5` — 自动停止前的最大迭代次数

**循环工作原理：**
1. Claude 按计划实现任务（`coding` 标签 → Claude，`analyze` 标签 → Codex）
2. Claude 写出工作摘要
3. Codex 审查摘要 — 如发现问题，Claude 收到反馈后继续
4. Codex 输出 "COMPLETE" 后，循环进入审查阶段
5. `codex review` 执行代码审查，标注 `[P0-9]` 严重度标记
6. 如发现问题，Claude 修复后继续
7. 当无问题残留或达到最大迭代次数时，循环结束

**其他常用参数：**
- `--yolo` — 跳过计划理解测验，让 Claude 直接回答 Codex 的问题（全自动模式）
- `--skip-quiz` — 仅跳过测验
- `--agent-teams` — 启用 Claude Code Agent Teams 并行开发
- `--skip-impl` — 跳过实现阶段，直接进入代码审查（适用于审查已有更改）

### 一键工作流（计划 + 循环一步到位）

如果你信任计划生成过程，可以一条命令从草稿到实施：

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md --auto-start-rlcr-if-converged
```

当计划收敛且无未解决分歧时，将自动启动 RLCR 循环。

### 监控进度

```bash
# 添加到 .bashrc 或 .zshrc（一次性设置）
source ~/.claude/plugins/cache/humania/humanize/*/scripts/humanize.sh

# 在另一个终端监控 RLCR 循环进度
humanize monitor rlcr
```

### 取消循环

```bash
/humanize:cancel-rlcr-loop
```

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
