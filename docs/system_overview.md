# barry-workflow 系统概览

> 本文目的：帮你在 5 分钟内建立对这套系统的全局认知，再引导你按需深入。
> 假设读者：会写代码，没用过这个仓库。

---

## 目录

- [§1 这套系统在干什么](#1-这套系统在干什么)
- [§2 五个 state 分别在干嘛](#2-五个-state-分别在干嘛)
- [§3 state 之间怎么跳转](#3-state-之间怎么跳转)
- [§4 控制 AI 遵守规则的机制](#4-控制-ai-遵守规则的机制)
- [§5 数据与文件结构](#5-数据与文件结构)
- [§6 自我进化闭环](#6-自我进化闭环)
- [§7 想看更深一层](#7-想看更深一层)

---

## §1 这套系统在干什么

**核心问题**：Claude Code 是一个强大但容易"跳步"的 AI——它会跳过分析直接改代码，跳过验证直接交付，出了 bug 也不知道怎么复盘。这套系统（barry-workflow）通过把 AI 锁进一个有限状态机（FSM）来解决这个问题：每次对话被划分成若干 **state**（状态），AI 在每个 state 只能做被允许的事，做完才能"升级"到下一个 state。

**四个核心概念**：
- **state**：AI 当前所处的工作阶段（BOOT / PREPARE / REFLECT / EXECUTE_LOOP / RECORDING / END），每个 state 有明确的允许/禁止工具清单。
- **FSM**（有限状态机）：state 之间的流转规则，由 AI 主动调用 `transition.sh` 触发，不能自行跳转。
- **rebuttal**（反驳协议）：AI 起草计划或完成执行后，强制派一个子 agent 来挑毛病，双方 N 轮对话后才算达成共识。
- **ledger**（台账）：每个任务下的一组 markdown 文件，记录意图日志、已验证的修复、踩过的坑。

**我们想达到的效果**：AI 不能跳过中间步骤直接交付；每一步都留下可审计的记录；历史教训跨 session 积累并在下次被复读。

---

## §2 五个 state 分别在干嘛

### BOOT — 定向，不修改任何东西

**目的**：读懂任务背景，不允许做任何修改。  
**允许**：Read / Grep / Glob，以及 `ls` / `cat` 等只读 Bash 命令。  
**禁止**：所有 Edit / Write，以及启动子 agent 或长任务。  
**离开条件**：读完 CLAUDE.md / goal.md，写下 `[BOOT_NOTE complexity=<class>]`（复杂度分类还决定了 EXECUTE_LOOP 里会加载哪个场景补丁），调 `transition.sh BOOT_DONE`。

深入阅读：[router_BOOT.md](../content/rules/router_BOOT.md)（注入给 AI 的精简规则卡片）/ [states/boot.md](../content/rules/states/boot.md)（完整的步骤规约与检查清单）

---

### PREPARE — 规划，不执行

**目的**：根据 BOOT 读到的背景，建立 cache_hit_map（即一张"哪些文件已读过、可复用"的清单）并起草执行计划，不允许实际修改项目代码。  
**允许**：Read / Glob / Grep / WebSearch，把计划草稿写进 action.md。  
**禁止**：Edit / Write 到项目源码，不能启动后台任务或测试。  
**离开条件**：计划通过 REFLECT rebuttal 后，调 `transition.sh PREPARE_DONE`。

深入阅读：[router_PREPARE.md](../content/rules/router_PREPARE.md)（精简规则卡片）/ [states/prepare.md](../content/rules/states/prepare.md)（完整规约）

---

### REFLECT — 反驳，主线程不写文件

**目的**：对计划或执行结果进行批判性复核，由主线程提问、子 agent 来挑毛病，至多 N 轮对话。  
**允许**：Read + 调 `Agent(run_in_background=true)` 派 rebuttal 子 agent + SendMessage。  
**禁止**：Edit / Write / Bash 写操作——所有修改必须等到 REFLECT_DONE 之后再做。  
**离开条件**：子 agent 和主线程达成共识（`[CONSENSUS_REACHED]`），调 `transition.sh REFLECT_DONE`。

深入阅读：[router_REFLECT.md](../content/rules/router_REFLECT.md)（精简规则卡片）/ [states/reflect.md](../content/rules/states/reflect.md)（完整的 N 轮 rebuttal 协议）

---

### EXECUTE_LOOP — 执行，每步留记录

**目的**：按计划做实际工作，每一步遵循 `[PLAN] → 工具调用 → [OBSERVE]` 三件套。  
**允许**：所有工具，但每个修改/长 Bash 前必须先写 `[PLAN]`，完成后写 `[OBSERVE]`。  
**禁止**：无工具限制，但违反 `[PLAN]`/`[OBSERVE]` 规范会被 hook 警告；连续 3 次失败必须停下来汇报。  
**离开条件**：交付完成或遇到异常，调 `transition.sh EXECUTE_EXIT` → 进入 RECORDING 写台账（v2.4 强制经过，不直接回 REFLECT）。

深入阅读：[router_EXECUTE_LOOP.md](../content/rules/router_EXECUTE_LOOP.md)（精简规则卡片）/ [states/execute.md](../content/rules/states/execute.md)（PLAN/OBSERVE 循环与 3 次失败停止规则）

---

### RECORDING — 台账写入（v2.4 新增）

**目的**：在任务完成（或中途）专注写台账，确保不漏记。  
**允许**：Read + 追加写 workspace 台账（bitter_lessons / successful_fixes / attempts_ledger / rule_violations）+ global ledgers。  
**禁止**：项目源码修改、新 Agent spawn、新执行工作。  
**离开条件**：写完台账 → `RECORD_DONE` → END（session 收尾路径）；或 `BACK_TO_LOOP` → 恢复 `prev_status` 继续执行（中途路径）。

深入阅读：[router_RECORDING.md](../content/rules/router_RECORDING.md)（精简规则卡片）/ [states/recording.md](../content/rules/states/recording.md)（4 问自查 + 出口决策）

---

### END — 最终汇报

**目的**：发最终 user-facing 总结，关闭 session。台账写入已在 RECORDING 完成，END 不再写台账。  
**允许**：Read + SendMessage 最终汇报。  
**禁止**：新执行、新 Agent spawn、项目源码修改、台账写入（RECORDING 已做）。  
**离开方式**：新的用户提示会开一个新 sid 从 BOOT 开始；同 session 切换任务用 `RESET_TO_BOOT`。

深入阅读：[router_END.md](../content/rules/router_END.md)（精简规则卡片）/ [states/end.md](../content/rules/states/end.md)（最终汇报步骤）

---

## §3 state 之间怎么跳转

```
BOOT ──BOOT_DONE──▶ PREPARE ──PREPARE_DONE──▶ REFLECT ◄══════════► EXECUTE_LOOP
  ▲                                               │  ▲ NEED_RECORD      │
  │                                               ▼  │                  ▼ EXECUTE_EXIT (强制经过)
  │                                            RECORDING ◄──────────────┘
  │                                               │ RECORD_DONE        ▲
  │                                               ▼                    │ BACK_TO_LOOP
  │                                              END                   │
  └──────────────────────────────RESET_TO_BOOT──────────────────────────┘
```

| 事件 | 含义 |
|------|------|
| `BOOT_DONE` | BOOT 检查清单全部完成 |
| `PREPARE_DONE` | 计划通过 rebuttal，准备执行 |
| `REFLECT_DONE` | 反驳协议达成共识 |
| `EXECUTE_EXIT` | 本轮执行结束（完成/异常/卡住）→ **RECORDING**（v2.4 强制经过，不再直接回 REFLECT） |
| `NEED_RECORD` | 中途需要写台账 → RECORDING（完成后 `BACK_TO_LOOP` 返回） |
| `RECORD_DONE` | RECORDING 台账写完 → END |
| `BACK_TO_LOOP` | RECORDING 中途完成 → 恢复 `prev_status` 继续工作 |
| `RESET_TO_BOOT` | 用户换了任务或更新了 goal.md，重读输入 |

跳转由 AI 主动调用 [`hooks/transition.sh`](../hooks/transition.sh) — 该脚本读取当前 state.md，修改 YAML 块中的 `current_status` 字段，原子写回，并将新状态 echo 到 stdout 供主线程确认。

---

## §4 控制 AI 遵守规则的机制

### §4.1 概览

系统靠三类东西约束 AI 行为：① **router 文本注入**（router 是一段规则文本，由 hook 在每次对话开始时自动插入 AI 上下文，相当于"当前状态说明书"）；② **hook 软提醒**（hook 是 Claude Code 在特定事件时自动执行的 shell 脚本，在工具调用前后发出警告，不阻断执行）；③ **AI 自觉**（always-on 横切规则，AI 内化执行）。

---

### §4.2 router 文本注入

[`hooks/inject_router.sh`](../hooks/inject_router.sh) — 每次 UserPromptSubmit 事件触发：读当前 state.md 中的 `current_status`，把对应的 `router_<STATUS>.md` cat 进 AI 上下文。若无 state 文件则回退到通用 `router.md`。

每个 `router_<STATE>.md` 的结构：
- 当前 state 的快速规则（允许/禁止工具清单）
- 离开条件与 transition.sh 调用示例
- 结尾附 always-on footer（四条横切规则，见 §4.4）

六个 router 文件：[router_BOOT.md](../content/rules/router_BOOT.md)、[router_PREPARE.md](../content/rules/router_PREPARE.md)、[router_REFLECT.md](../content/rules/router_REFLECT.md)、[router_EXECUTE_LOOP.md](../content/rules/router_EXECUTE_LOOP.md)、[router_RECORDING.md](../content/rules/router_RECORDING.md)、[router_END.md](../content/rules/router_END.md)。

---

### §4.3 hook 软提醒

**PreToolUse — [`hooks/pretooluse_short_nudge.sh`](../hooks/pretooluse_short_nudge.sh)**  
每次工具调用前触发，按工具类型最多塞一行 ≤100 字符提醒（例如：连续 Read 超过阈值时提示"要不要派子 agent"；Edit 前没有写 `[PLAN]` 时提醒先写），永不 block，`permissionDecision` 始终为 `allow`。

**PostToolUse — [`hooks/state_enforce.sh`](../hooks/state_enforce.sh)**  
工具调完后触发，对照当前 state 检查是否使用了禁用工具（例如：REFLECT 中用了 Edit），在 stderr 喷一行警告，不阻断。

**AI 手动调 — [`hooks/execute_loop_audit.sh`](../hooks/execute_loop_audit.sh)**  
AI 在 EXECUTE_LOOP 中按需调用，扫 action.md 中的 `[PLAN]`/`[OBSERVE]` 计数以及异常关键词命中数，辅助判断是否触发 3 次失败停止规则。

---

### §4.4 横切 always-on 规则

每个 router 文件末尾都附同一段 footer，四条规则始终有效：

- [facts_first.md](../content/rules/facts_first.md) — 每个 `[INFERENCE]` 必须通过 INFERENCE_GATE 四步检查（列证据 → 充分性 → mini rebuttal → 引用脚注），禁止把假设当事实。
- [dispatch.md](../content/rules/dispatch.md) — 超过 1 个文件读取 / WebSearch / 代码变更，必须通过 `Agent(run_in_background=true)` 派子 agent 执行，主线程不直接做。
- [recording.md](../content/rules/recording.md) — 每个操作前先在 action.md 写 `[PLAN]`，每个 reply 开头读并写 `[BOARD_READ]`（BOARD 即 action.md 操作日志，类似公告板），任务收尾必须更新台账或写 `[no new ledger entries]`。
- lessons.md grep — 在回复用户或写交付物之前，grep `~/.claude/rules/lessons.md` 中的 `tags:` 字段，找与当前任务相关的历史教训并遵守。

---

## §5 数据与文件结构

三个存储位置各司其职：

**`.barry_workflow/<sid>/`** — per-session（`<sid>` 是 session id，见 §1），session boot hook 自动创建
- `state.md` — FSM 当前状态 + YAML 元数据（`current_status` / `stage_history` / `cache_hit_map`）
- `action.md` — 本 session 的操作日志（`[PLAN]` / `[OBSERVE]` / `[BOARD_READ]`）
- `nudge_counters.json` — pretooluse_short_nudge 的工具调用计数

**`workspace/`** — 仓库级共享 ledger，跨 session 跨 task 长期保留（每次 UserPromptSubmit 由 `hooks/session_boot.sh` 幂等检查并补齐缺失文件；`scripts/new_task.sh` 也会做同样的 seeding 作为兜底）
- `bitter_lessons.md` — 项目级技术陷阱（L-N，每条带 `task: <name>` + `tags:`）
- `successful_fixes.md` — 已验证有效的修复（FIX-N + `task:` + `tags:`）
- `attempts_ledger.md` — 每轮意图记录（ATT-N + `task:` + `tags:`）
- `rule_violations.md` — 本项目 AI 行为失误（W-N + `task:` + `tags:`）

**`workspace/<task>/`** — per-task 子目录
- `goal.md` — 用户撰写的任务目标，AI 只读（由 `new_task.sh` 从模板创建）

**`~/.claude/`** — 全局，跨项目
- `CLAUDE.md` — 部署后的全局 router 总纲（从 `content/CLAUDE.md` 同步）
- `rules/` — 部署后的横切规则集（facts_first / dispatch / recording / lessons / violation 等）
- `hooks/` — 部署后的 8 个 hook 脚本

详细文件表格（含 `set_claude.sh` 部署路径映射）见 [README.md](../README.md) 中的文件结构章节。

---

## §6 自我进化闭环

当 AI 在某个项目里踩了坑（配置冲突、库 bug、错误诊断路径），记录进 `workspace/bitter_lessons.md`（仓库共享，所有 task 共用一份；每条 entry 带 `task: <name>` + `tags:`）。高价值的教训可以提炼成 patch，放到 [`content/rules/patches/`](../content/rules/patches/)（目前有 5 个场景补丁：`bug_debug.md` / `perf_debug.md` / `long_monitor.md` / `simple_fast.md` / `exploration.md`）。下次 session 在 BOOT 阶段根据任务复杂度分类自动拉取对应 patch，从而收窄 AI 的行为分布。

触发机制由用户主动起草补丁（未来计划通过 `scripts/` 下的 `/gen-patch-draft` skill 半自动化）。

---

## §7 想看更深一层

| 你想知道 | 读这个文件 — 一句话说明 |
|----------|-----------|
| rebuttal 协议具体怎么 N 轮判停 | [`content/rules/states/reflect.md`](../content/rules/states/reflect.md) — REFLECT state 完整规约，含轮次预算、CONSENSUS 判定与 INFERENCE_GATE 迷你 rebuttal |
| INFERENCE_GATE 是什么（如何判断推断合法） | [`content/rules/facts_first.md`](../content/rules/facts_first.md) — 定义 [FACT]/[INFERENCE]/[ASSUMPTION] 标签规则与 4 步 INFERENCE_GATE 检查流程 |
| EXECUTE_LOOP 的 `[PLAN]`/`[OBSERVE]` 循环细节 | [`content/rules/states/execute.md`](../content/rules/states/execute.md) — 迭代模式、3 次失败停止规则与 Monitor 监控节奏 |
| 场景补丁怎么用（5 个示例） | [`content/rules/patches/`](../content/rules/patches/) — 5 个场景专用附加规则，覆盖 bug_debug / perf_debug / long_monitor / simple_fast / exploration |
| 全部可调参数（超时、轮次、阈值） | [`content/rules/workflow_config.yaml`](../content/rules/workflow_config.yaml) — YAML 格式的系统参数，包括 rebuttal 轮次上限、nudge 计数阈值等 |
| session_boot hook 怎么创建 state 文件 | [`hooks/session_boot.sh`](../hooks/session_boot.sh) — session 首次 UserPromptSubmit 时自动创建 .barry_workflow/<sid>/ 目录与 state.md |
| 子 agent 有哪些约束 | [`content/rules/subagent_rules.md`](../content/rules/subagent_rules.md) — 子 agent 必须遵守的 8 条规则（verbatim prompt / 异步汇报 / 沉默声明等） |
| 历史违规记录（AI 踩过的坑） | [`content/templates/global_rules/violation.md`](../content/templates/global_rules/violation.md) — 全局 AI 行为违规记录（W-XXX + tags），是 repo 侧的写入源文件 |
