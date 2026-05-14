<p align="center">
  <img src="docs/img/bp_hero.png" alt="Barry's Workflow" width="780"/>
</p>

<h1 align="center">Barry's Workflow — Claude Code Edition</h1>

<p align="center">
  把 AI coding agent 从「条件反射机器」变成「会自我反思的状态机」。<br/>
  对抗训练集偏见，阻止「觉得自己做对了」的错觉，用文档自我进化。
</p>

<p align="center">
  <a href="docs/big_picture.html"><b>📖 big_picture</b></a> ·
  <a href="docs/scenarios.html"><b>🎬 scenarios</b></a> ·
  <a href="docs/implementation.html"><b>🔧 implementation</b></a> ·
  <a href="docs/p8_e2e_notes.md"><b>✅ P8 demo 报告</b></a> ·
  <a href="README.md"><b>🇬🇧 English</b></a>
</p>

---

## 目录

- [1. 为什么 — 跳步病 (skip-to-done)](#1-为什么--跳步病-skip-to-done)
- [2. 整体思路](#2-整体思路)
- [3. 它实际在做什么](#3-它实际在做什么)
- [4. 安装](#4-安装)
- [5. 日常用法](#5-日常用法)
- [6. 预期表现（来自 P8 demo）](#6-预期表现来自-p8-demo)
- [7. 安装我自己的 skills](#7-安装我自己的-skills)
- [8. 卸载 / 关掉只用纯 claude](#8-卸载--关掉只用纯-claude)
- [9. 深入了解](#9-深入了解)

---

## 1. 为什么 — 跳步病 (skip-to-done)

<img src="docs/img/bp_motivation.png" alt="motivation" width="100%"/>

LLM 的训练数据里大多是「问题 + 修好后的代码」的成品 pair，缺少**中间的诊断 / 试错 / 复测**步骤。所以默认行为就是「**跳到结论**」：

- 没跑测试就说"已修复"
- 没看 console 输出就声明"OK"
- 改错位置 / 改了一堆无关文件还说"按你说的做了"
- 并行开 10 个 AI 想看不同思路，结果 10 个走的是**同一条歪路**（entropy collapse）

光靠在 prompt 里写「请仔细思考」不行——训练分布会把它推回原样。

<details>
<summary>🧠 entropy collapse 是什么</summary>

<img src="docs/img/bp_entropy.png" alt="entropy collapse" width="100%"/>

</details>

---

## 2. 整体思路

**AI 是条件生成（conditional generation）模型。** 输出分布完全由输入决定——prompt、上下文、读入的文件，这些就是"条件"。"状态"不过是当前激活的条件集合的名字。控制状态 = 控制条件 = 把分布收窄到我们真正需要的输出。

Barry's Workflow 提供**两类条件**，缺一不可：

| 条件来源 | 包含什么 | 作用 |
|---|---|---|
| **A — 设计好的工作流** | FSM 规则、按 state 注入的 router、`[PLAN]/[OBSERVE]` 纪律、REFLECT rebuttal 协议 | 硬底线。把训练数据里没有的中间步骤强制补回来。静态、人工设计。 |
| **B — 自我进化文档** | `workspace/<task>/bitter_lessons.md`、`successful_fixes.md`、`rule_violations.md`、`patches/*.md` | 每次 session 进一步收窄分布。每条积累的经验都把 AI 从训练集默认轨道推向「这个代码库里真正有效的做法」。随时间增长。 |

两类条件都必须有。工作流给 AI 正确的结构；自我进化文档给 AI 对当前项目正确的先验知识。

**自我进化闭环**（条件来源 B）：

```
session 踩到一个意外的坑
  → AI 记到 workspace/<task>/bitter_lessons.md（L-N 条目 + tags）
  → 下次 session：BOOT 阶段读 bitter_lessons.md → 分布收窄
  → 如果坑反复出现：AI（或用户）起草一个 patch 到 content/rules/patches/
  → patch 升级为 active → 之后的 session 作为条件注入
  → 分布永久进一步收窄
```

Entropy collapse 的根源之一就是自我进化失败：没有项目特定知识积累，每次 session 都从同一个 vanilla 分布出发，犯同样的错。

附加一个**反「觉得自己做对了」**的机制：

<details open>
<summary><b>Clean-Context Rebuttal — 派一个不知道上下文的 AI 当审稿人</b></summary>

<img src="docs/img/bp_rebuttal.png" alt="rebuttal" width="100%"/>

</details>

---

## 3. 它实际在做什么

整个 session 是一个 FSM。每次状态切换都调用 `hooks/transition.sh`，每轮 prompt 注入当前 state 的 router，告诉 AI **现在能干什么、不能干什么、怎么进下一步**。

### FSM 状态机

```mermaid
flowchart LR
    BOOT[BOOT<br/>读上下文]
    PREPARE[PREPARE<br/>列计划 + 缓存]
    REFLECT[REFLECT<br/>派 subagent rebuttal]
    EXECUTE[EXECUTE_LOOP<br/>PLAN → 工具 → OBSERVE]
    END[END<br/>归档 + ledger]

    BOOT --> PREPARE --> REFLECT --> EXECUTE
    EXECUTE -- "异常 / 完成<br/>回 REFLECT" --> REFLECT
    EXECUTE --> END

    classDef state fill:#eef6ff,stroke:#0969da,color:#0a2540;
    classDef terminal fill:#e6ffec,stroke:#1a7f37,color:#0a3d1f;
    class BOOT,PREPARE,REFLECT,EXECUTE state
    class END terminal
```

### 通用状态机 + 场景补丁

<img src="docs/img/bp_fsm_patches.png" alt="state machine + patches" width="100%"/>

5 个 scenario patch（`content/rules/patches/`）针对特定任务类型 override 默认行为。可以**人工写**，也可以由 AI 把 `bitter_lessons.md` 反复出现的坑**自动起草**为补丁——这构成自我进化闭环。

### 一次 session 留下什么

```
.barry_workflow/<sid>/
├── state.md              YAML: 当前 state + 历史 + cache_hit_map
├── action.md             逐步 [PLAN] / [OBSERVE] 日志
├── transitions.log       每次 state 转换的 3 行摘要（FSM 时间线）
└── reflection_*.md       REFLECT 阶段的 rebuttal 记录

workspace/<task>/         （跨 session 长期存活，git tracked）
├── goal.md               用户写，main 只读
├── bitter_lessons.md     L-N + tags：项目踩过的坑
├── successful_fixes.md   FIX-N + tags：确认有效的修法
├── attempts_ledger.md    ATT-N + tags：尝试过什么（跨 turn 意图日志）
└── rule_violations.md    W-N + tags：本项目 AI 行为错误
```

---

## 4. 安装

### 前置

```bash
npm install -g @anthropic-ai/claude-code
```

### 部署

```bash
git clone https://github.com/gyy0592/claude-config.git ~/Programs/claude-config
cd ~/Programs/claude-config
bash set_claude.sh
```

`set_claude.sh` 会做：

1. 拷贝 8 个 hook 到 `~/.claude/hooks/`，sed 替换 `__CLAUDE_CONFIG_DIR__` 为实际仓库路径
2. 同步规则文件到 `~/.claude/rules/`（router/states/patches/messages 全部）
3. 在 `~/.claude/settings.json` 注册 4 个 hook（UserPromptSubmit / PreToolUse / PostToolUse）
4. 把已有的 `~/.claude/rules/violation.md + lessons.md` 跟仓库版本做 diff，冲突时询问保留方向（非交互场景自动以仓库为准）

### 升级 / 重部署

```bash
cd ~/Programs/claude-config && git pull && bash set_claude.sh
```

idempotent，反复跑安全。

### 从旧版（v1 cosplay 规则）迁移

```bash
bash cleanup_v1.sh          # 清掉旧 hook + ~/.claude_status/ runtime 残留
bash set_claude.sh          # 再部署 v2
```

---

## 5. 日常用法

### 进入一个项目

第一次在某个 repo 里跑 `claude` 时，session_boot hook 会自动建：

```
.barry_workflow/<session-id>/{state,action,transitions.log}
```

只在有 `.git` / `CLAUDE.md` / `workspace/` 的目录建（避免污染随便目录）。

### 长期任务用 workspace ledger

为某个长期项目（比如 stage1 训练优化、某个论文复现）建一个 task 目录：

```bash
mkdir -p workspace/<task_name>
echo "<你的目标>" > workspace/<task_name>/goal.md
```

`goal.md` 是 user 控制，main 只读。其他 ledger（`bitter_lessons / successful_fixes / attempts_ledger / rule_violations`）会随着 AI 工作积累。

### 关掉 hook 临时用纯 claude

简单一次性任务嫌 FSM 麻烦：

```bash
bash scripts/switch_hooks.sh off       # 删掉 4 个 hook 注册
bash scripts/switch_hooks.sh on        # 加回来
bash scripts/switch_hooks.sh status    # 看现在哪些活着
```

只动 `~/.claude/settings.json` 的 hooks 段，**规则文件 + hook 文件本体 + bg-bash 日志 hook** 都保留。

### 看 AI 这轮做了什么

```bash
# 抓干净的对话（用户消息 + AI 文本 + 工具调用 + 工具返回）
python3 scripts/extract_transcript.py \
  ~/.claude/projects/<encoded-cwd>/<sid>.jsonl \
  --tool-result-lines 5 --no-system-reminder

# 看 FSM 时间线（每次 state 切换 + tool_use 计数 + 转移前最后一句话）
cat .barry_workflow/<sid>/transitions.log
```

### 浏览器看 session（viewer）

`viewer/` 是个 3 栏的本地 HTML 查看器（左 agent 树 / 中上 state + reflection / 中下干净 transcript）。一键启动：

```bash
bash scripts/start_viewer.sh          # 自动选空端口，打印 URL
bash scripts/start_viewer.sh status   # 看 pid 跟端口
bash scripts/start_viewer.sh stop     # 杀掉
```

如果是 SSH 进的服务器，本地终端先开端口转发：  
`ssh -L <port>:localhost:<port> user@host`，然后浏览器打开打印出的 URL。

默认 sample 是 P8 demo session。要看自己的 session，把数据放到 `viewer/data/<sid>/` 即可。

---

## 6. 预期表现（来自 P8 demo）

一次真实端到端测试：让一个全新的 cloud claude（带本仓库 v2 hooks）自己把一个已有的 repo 接入 v2 ledger 体系。

**4 项核心 check 全部 PASS**：

| Check | 结果 | 证据 |
|---|:--:|---|
| FSM 5 阶段全走完 | ✅ | `stage_history` 5 entries: BOOT_DONE → PREPARE_DONE → REFLECT_DONE(pre) → EXECUTE_EXIT → REFLECT_DONE(post) |
| Router 注入按 state 切换 | ✅ | transcript 多次 `[ROUTER · state=X]` |
| Subagent 派得动 | ✅ | 2 次 `Agent(run_in_background=true)`：REFLECT rebuttal + EXECUTE 建 ledger |
| session_boot 自动建文件 | ✅ | 首轮 UserPromptSubmit 后 `.barry_workflow/<sid>/{state,action}.md` 出现 |

**交付**：5 个 ledger（带 L-N / W-N / FIX-N / ATT-N + tags）+ legacy 归档目录 + 5 个 `[PLAN]/[OBSERVE]` 配对。

**实际开销**：18 min wall-clock，~250K tokens（含 2 个 subagent）。

---

## 7. 安装我自己的 skills

`skills/` 下是 30+ 个**复用 skill**（censor 审计 / code-tree 代码地图 / efficiency-audit 性能审计 / 等等）。装法是 symlink 到 `~/.claude/skills/`：

```bash
mkdir -p ~/.claude/skills
for s in ~/Programs/claude-config/skills/*/; do
  name=$(basename "$s")
  ln -sfn "$s" ~/.claude/skills/"$name"
done
```

也可以挑某几个装：

```bash
ln -sfn ~/Programs/claude-config/skills/censor          ~/.claude/skills/censor
ln -sfn ~/Programs/claude-config/skills/code-tree       ~/.claude/skills/code-tree
ln -sfn ~/Programs/claude-config/skills/efficiency-audit ~/.claude/skills/efficiency-audit
```

skill 的触发逻辑都在各自目录的 `SKILL.md` frontmatter `description` 里——Claude 见到匹配语境自动调。

清单详见 [`docs/skills.md`](docs/skills.md) / [`docs/skills.zh.md`](docs/skills.zh.md)。

---

## 8. 卸载 / 关掉只用纯 claude

**临时关**（保留所有文件，只是 hook 不触发）：

```bash
bash scripts/switch_hooks.sh off
```

**完全卸载**：

```bash
bash scripts/switch_hooks.sh off
rm -rf ~/.claude/hooks/{inject_router,session_boot,pretooluse_short_nudge,state_enforce,transition,prepare_helper,execute_loop_audit,_session_lib}.sh
rm -rf ~/.claude/rules/{router*.md,states,patches,messages,facts_first.md,dispatch.md,recording.md,subagent_rules.md,failure_stop.md,fsm.md,prompt_enhancement.md,codex_adapter.md,workflow_config.yaml,subagent_rules.md}
# 用户内容保留:
# ~/.claude/rules/violation.md   ← 跨项目 W-XXX
# ~/.claude/rules/lessons.md     ← 跨项目 L-XXX
```

不会动 `~/.claude/skills/`（symlink）— skill 是独立装的。

---

## 9. 深入了解

| 文档 | 给谁 | 内容 |
|---|---|---|
| [`docs/big_picture.html`](docs/big_picture.html) | 非工程师 / 初次了解的人 | 动机 + entropy collapse + 两个核心原则 + 设计哲学 |
| [`docs/scenarios.html`](docs/scenarios.html) | 想知道理想行为 | 5 个场景的 state-by-state 预期 + 常见陷阱 |
| [`docs/skills.md`](docs/skills.md) / [`docs/skills.zh.md`](docs/skills.zh.md) | skill 使用者 | 完整 skill 清单 + 触发条件 |

---

<p align="center"><i>由 <a href="https://github.com/gyy0592">@gyy0592</a> 维护。bug / 改进建议欢迎开 issue。</i></p>
