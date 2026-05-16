# fail_cases_2.5.md — v2.5 机制为什么经常失效

> 这份文档是诊断报告，不动手修任何东西。  
> 调查任务名：`fsm_audit_2_5`，目标定义在 `workspace/fsm_audit_2_5/goal.md`。  
> 调查过程中跑过一轮对抗 rebuttal subagent，它的回复存在 `.barry_workflow/9de8c81e-.../reflection_r1-pre-task-2026-05-16T05-15Z.md`。

## 0. 先解释几个关键名词（避免后文黑话）

读这份报告前你需要知道这几个东西大概是什么：

- **FSM = Finite State Machine（状态机）**。我们的工作流被切成 6 个 state（阶段）：BOOT → PREPARE → REFLECT → EXECUTE_LOOP → RECORDING → END。每个 state 有自己"该干啥 / 不该干啥"的规则。
- **state.md**：每个 session（claude 一次对话）都有一份。路径是 `.barry_workflow/<session-id>/state.md`。里面 YAML 字段 `current_status:` 记录现在在哪个 state。AI 每次想换 state 必须跑 `transition.sh` 改这个字段。
- **transition.sh**：脚本 `hooks/transition.sh`。AI 用 `bash hooks/transition.sh BOOT_DONE` 这种命令切 state。脚本会改 state.md 的 `current_status:` 字段。
- **router_XXX.md**：每个 state 一个，路径 `content/rules/router_<state>.md`。比如 `router_REFLECT.md`。这是**每次用户说话**时 hook 自动塞到 AI 上下文里的"你现在在 REFLECT 状态，允许 X 禁止 Y"的提示。AI 整轮对话里能直接看到。
- **states/XXX.md**：每个 state 一个，路径 `content/rules/states/<state>.md`。比如 `states/reflect.md`。这是这个 state **完整的工作流程文档**，比 router_XXX.md 详细 10 倍。**只有在 AI 跑 `transition.sh` 切到这个 state 的瞬间**才被 cat 一次塞进上下文。之后这份文档在 AI 上下文里待多久看 token 是否被挤掉。
- **hook**：claude 的 settings.json 里可以挂的脚本。比如每次用户提交 prompt 时（UserPromptSubmit）、每次 AI 调一个工具前（PreToolUse）/ 后（PostToolUse）触发跑某个 shell 脚本，脚本输出会塞进 AI 上下文。
- **ledger（记账文件）**：4 个文件：
  - `workspace/bitter_lessons.md` — 项目里踩过的技术坑（OOM、库不兼容、硬件怪事）
  - `workspace/successful_fixes.md` — 已确认有效的修法
  - `workspace/rule_violations.md` — AI 自己违反工作流规则的记录
  - `workspace/attempts_ledger.md` — AI 每次任务尝试的简短日志
- **rebuttal / 对抗审查**：AI 在 REFLECT 状态时要派一个 subagent 来挑自己计划的毛病。AI 把计划写到一个 `reflection_*.md` 文件里，subagent 读完写回复，AI 看完决定继续或采纳意见。

## 本质分类（用户口径）

5 个 fail mode 其实就两类：

### 类 A — state 间该切的时候没切（状态机跳跃错位）

| # | 一句话 | 关键点 |
|---|-----|---------|
| **F3** | AI 在 EXECUTE_LOOP 阶段直接 Edit 了 ledger 文件，没有先切到 RECORDING | 本来该走 `EXECUTE_LOOP → 跑 transition.sh NEED_RECORD → 进 RECORDING → 在 RECORDING 里 Edit → 跑 transition.sh BACK_TO_LOOP → 回 EXECUTE_LOOP`，但 AI 把中间 3 步跳过了 |
| **F4** | `transition.sh` 改错了 state.md 文件 | 多个 session 共存时，脚本靠 "哪个 state.md 文件最新被改过" 推断"当前 session"，导致改到不是当前会话的那一份 |

### 类 B — 进对了 state 但做错了事

| # | 一句话 | 关键点 |
|---|-----|---------|
| **F1** | 进了 BOOT 但还在 Edit/Write 文件 | BOOT 应该只读不写，AI 直接动手改文件 |
| **F2** | 进了 REFLECT 但没派 rebuttal subagent | REFLECT 这个 state 的**唯一**职责就是派 subagent 做对抗审查，AI 经常直接 transition 走人 |
| **F5** | rebuttal 这个机制本身设计太复杂 → 进一步劝退 AI 不照做（是 F2 的二阶原因） | subagent 写完回复后必须 `sleep 30` 循环等用户 SendMessage 而不能直接退出，AI 一看到要管这种长跑后台进程就直接绕过整个 REFLECT |

## 1. 用户原始口径（逐字）

1. **F1 — BOOT 初始化经常坏**：要么不做 BOOT 该做的事（不读 ledger、不更新 cache_hit_map），要么所有事都在 BOOT 阶段做了（应该只读不写，结果在 BOOT 里写代码）。【类 B】
2. **F2 — REFLECT 经常被跳过 rebuttal**：进了 REFLECT 后 AI 不派 rebuttal subagent，直接做别的或者干脆 transition 走了。REFLECT 应该**只做**派 subagent 这一件事。【类 B】
3. **F3 — 本应在 RECORDING 做的事漏到了 EXECUTE_LOOP**：AI 在 EXECUTE_LOOP 中识别到要写 ledger（比如想登一条 bitter_lesson）时，不跑 `transition.sh NEED_RECORD` 先切到 RECORDING，而是直接在 EXECUTE_LOOP 里 Edit 了 ledger 文件。**问题是该切 state 时没切**，不是 RECORDING 没人进。【类 A】

调查过程中又发现 2 个：

4. **F4 — transition.sh 改错 session**：本次调查的 BOOT 阶段直接复现到的现象。【类 A】
5. **F5 — REFLECT 的对抗审查 protocol 太重**：rebuttal subagent 必须 `while true; do sleep 30; done` 等用户/main 主动 SendMessage 而不能写完就退，让 main 必须管理一个挂着的后台进程。本次调查里用户直接 kill 了 subagent（"为啥你的后台 agent 进入了 while sleep"），这就是这条的现场证据。【类 B，F2 的二阶原因】

## 2. 五个 fail mode 各自详述

---

### F1 — BOOT 里写文件（应只读）

**这个 state 是干啥的**：BOOT 是 session 第一个 state，作用是"我刚醒过来，先读一遍上下文（CLAUDE.md / goal.md / ledgers / cache_hit_map），然后判断这个任务多难，再走下一步"。规则是**只能 Read 不能 Write**。

**症状（用户观察到的）**：AI 进了 BOOT，但是开始 `Edit` 或 `Write` 一个项目源文件。或者反过来，直接跳到 `BOOT_DONE` 但前面 `bitter_lessons.md` / `successful_fixes.md` 一个都没读。

**具体例子**：你给 AI 一个任务"修一下 main.py 这个 bug"。AI 进 BOOT，**应该**先读 `workspace/bitter_lessons.md` 看有没有 main.py 历史踩过的坑、读 `workspace/successful_fixes.md` 看有没有类似 bug 的修法、读 `goal.md`，再写一条 `[BOOT_NOTE complexity=bug_debug]` 到 action.md，最后才 `transition.sh BOOT_DONE`。**实际**：AI 一眼看到 main.py，直接 `Edit main.py` 改了，连 BOOT_DONE 都没跑。

**根因（注入内容层）**：
- `content/rules/router_BOOT.md:6`：禁令 `Forbidden = Edit/Write/mutators/Agent` 写在一行 "Quick rules" 里，被压在 router 中间，**第 1 行不是这个**。第 1 行是 `[ROUTER · state=BOOT] You are in BOOT. Read-only orientation, no mutations.` —— "Read-only orientation, no mutations" 这串字看起来像描述（"orientation 就是只读哈"）而不是命令（"禁止写"）。AI 长对话里上下文衰减后，只记得"我在 BOOT" 不记得"BOOT 禁止 Write"。
- `content/rules/states/boot.md:58-64`：完整的 Allowed/Forbidden 列表写得很清楚，但是**这份文件只在 AI 主动跑 `transition.sh RESET_TO_BOOT` 或者刚开 session 的瞬间被 cat 进上下文一次**，之后没人主动复读。

**根因（机制层）**：
- 现在没有任何 hook 在 BOOT state 下硬挡 Edit/Write。`hooks/state_enforce.sh` 是 PostToolUse hook（工具调完才跑），只往 stderr 打一行 warning "[state_enforce] BOOT state — Edit not allowed"。warning 是事后通知，AI 已经把文件改了。

**三层归因**：
| 层 | 角色 |
|---|---|
| 注入内容（router_BOOT.md） | **主因** — 禁令藏在 quick-rules，没顶到第 1 行 |
| 引用文档（states/boot.md） | 次因 — 写得对但只在 transition 时 cat 一次，常驻 router 没复述 |
| 机制（hook） | 末因 — 缺 PreToolUse deny hook 硬挡 |

---

### F2 — REFLECT 里不派 rebuttal subagent

**这个 state 是干啥的**：REFLECT 在 PREPARE 之后、EXECUTE_LOOP 之前。作用是"在我开始动手前，让一个 subagent 来挑我计划的毛病，避免冲昏头脑就开干"。规则是**这一整轮只能干一件事：派 subagent 做 rebuttal、读它的回复**。

**怎么做 rebuttal（按 protocol 应有的流程）**：
1. AI（main）写一个 `.barry_workflow/<sid>/reflection_r1-...md` 文件，里面填 `## main's questions` 段：3-7 个具体问题。
2. AI 调 `Agent(run_in_background=true, prompt=...)` 派一个后台 subagent，告诉它读这个 reflection 文件。
3. subagent 读完，在文件里追加 `## reviewer reply` 段写回复。
4. AI 读 subagent 回复，决定是否还要下一轮（按 `states/reflect.md:84-86` protocol，subagent 写完会 `while true; do sleep 30; done` 挂着等用户/main SendMessage 推进下一轮）。
5. AI 满意了，往文件里写 `[CONSENSUS_REACHED]`，然后 `transition.sh REFLECT_DONE` 进 EXECUTE_LOOP。

**症状**：AI 进了 REFLECT，**不**派 subagent，直接：(a) `transition.sh REFLECT_DONE` 跳过，或者 (b) 自己写了个 reflection 文件但是没派 agent，或者 (c) 自己边读边自问自答冒充 rebuttal。

**具体例子**：你给 AI 一个非平凡任务（比如"重构这个模块"），AI 走完 PREPARE 进 REFLECT。**应该**写 `reflection_r1-pre-task-...md`，填问题，然后 `Agent(...)` 派 subagent。**实际**：AI 心里想"我自己想过了不用 rebuttal 了"，直接 `bash hooks/transition.sh REFLECT_DONE --reason="straightforward port"` 跳过。`stage_history` 里有这种例子（看本仓库 `9de8c81e/state.md` history 的 `simple-no-rebuttal` 字样）—— AI 给自己找了"简单任务不需要 rebuttal"的理由。

**根因（注入内容层）**：
- `content/rules/router_REFLECT.md:1`：`[ROUTER · state=REFLECT] You are in REFLECT. Subagent-driven rebuttal, main writes no files.` —— "Subagent-driven rebuttal" 是描述性短语（"这个 state 是 subagent 主导的 rebuttal"），**不是命令**（"你必须派 subagent"）。
- `content/rules/router_REFLECT.md:9`：`Allowed = Read + Bash(transition.sh|ls|cat) + Agent(run_in_background=true) for rebuttal subagent + SendMessage.` —— Agent 是 Allowed（允许），不是 Required（要求）。AI 读完觉得"我有这工具，但用不用随我"。
- **router_REFLECT.md 自相矛盾（main 自己审计发现）**：
  - L1 + L9 两次说 "禁止 Edit/Write"。
  - 但 `content/rules/states/reflect.md:11` 的 protocol 要求 main 写 reflection 文件 + 填问题 —— 必须 Write/Edit。
  - 结果：守规矩的 AI 读完上下文发现"router 禁我 Write，protocol 又要我 Write"，干脆走 `transition.sh REFLECT_DONE` 直接退出 REFLECT 规避矛盾。**这刚好对应 F2 的症状**。
<!-- comment 这是明显的bug 要修复  -->
**根因（机制层 — v2.5 试图修但没修对）**：
- `hooks/pretool_reflect_nag.sh` 是 v2.5 新加的 PreToolUse hook（每次工具调用前跑）。它的逻辑：如果当前 state=REFLECT 且 session 里**还没派过 Agent**，就在工具调用前注一句"你忘了派 subagent"的短提示。
- 问题出在 `hooks/pretool_reflect_nag.sh:65-69` 这段：
  ```bash
  if ls "$SDIR"/reflection_*.md >/dev/null 2>&1; then
      exit 0
  fi
  ```
  意思是"只要这个 session 目录下存在任何叫 `reflection_*.md` 的文件，nag 就自我关闭"。**太宽松**。
<!-- 这根本不是我要的检测： 我说的很明确 还没有派过agent： 你必须检测的是agent tool的调用之类的  我不要任何可能会产生错误的检测 这是你的错  -->
- 出错场景：AI 刚 Write 一个空的 `reflection_r1-...md` 文件占位（还没 spawn agent），下次工具调用 nag 就检测到这个文件存在了，自动关闭——AI 失去了"该派 agent"的提醒。或者 session 里有个老的 `reflection_ig-*.md`（之前 INFERENCE_GATE 留下的）也会把 nag 哑掉。

**根因（引用文档层）**：
- `content/rules/states/reflect.md:11`：`main fills "## main's questions" with 3–7 specific questions` —— 这一步操作没说"**做完这件事这一轮其他什么 Write/Edit 都不能做**"。AI 可能填完问题觉得"还能再 Edit 几个别的文件"。

**三层归因**：
| 层 | 角色 |
|---|---|
| 机制（pretool_reflect_nag.sh） | **主因** — 自禁条件过宽，AI 一旦创建占位 reflection 文件就 nag 失效 |
| 注入内容（router_REFLECT.md） | 次因 — "Subagent-driven rebuttal" 不是命令 + L1/L9 与 protocol 自相矛盾 |
| 引用文档（states/reflect.md） | 末因 — 没明示"派 agent 前其他事都不能干" |

---

### F3 — 该切到 RECORDING 时没切（ledger 写漏到 EXECUTE_LOOP）【类 A】

**修正用户原话**：不是"RECORDING 没人进"——RECORDING 在 v2.4 之后 EXECUTE_EXIT 路径上几乎一定会被进入。**真问题是 AI 在 EXECUTE_LOOP 进行中遇到"该记账"的时刻时不切**。

**这个 state 是干啥的**：RECORDING 在 v2.4 加进来，专门用于写 ledger（bitter_lessons / successful_fixes / rule_violations / attempts_ledger）。设计意图：把"写 ledger"和"做实际任务"在 FSM 上隔开，避免 AI 把 ledger 当成普通文件改。

**症状**：AI 在 EXECUTE_LOOP 中做任务，做到一半识别出"这里有个坑值得记下来"，**应该**先跑 `transition.sh NEED_RECORD` 切到 RECORDING、在 RECORDING 里 Edit ledger、再 `BACK_TO_LOOP` 切回 EXECUTE_LOOP 继续任务。**实际**：AI 直接在 EXECUTE_LOOP 里 `Edit workspace/bitter_lessons.md`，state.md 的 `current_status:` 始终是 `EXECUTE_LOOP`，RECORDING 在 `transitions.log` 里那段时间完全没出现。

**具体例子**：AI 在调一个新的库 OOM，发现"原来这个库默认开了 KV cache 必须显式关"。**应该**走 `EXECUTE_LOOP → NEED_RECORD → RECORDING (Edit bitter_lessons.md 加一条 L-N) → BACK_TO_LOOP → EXECUTE_LOOP`，5 个事件。**实际**：直接 `Edit workspace/bitter_lessons.md` 加一条，然后继续干活，0 个 transition 事件。`transitions.log` 上看不到任何 RECORDING 痕迹。

**根因（注入内容层）**：
- `content/rules/router_EXECUTE_LOOP.md:14-17` 逐字：
  ```
  Recording reminder (always-on in EXECUTE_LOOP):
    本轮有无任何记账值得做? — 项目技术坑 / 成功 fix / AI 自身违规 / 跨项目智慧
    → 有 → bash ~/.claude/hooks/transition.sh NEED_RECORD --reason="<one-line>" 进 RECORDING (then BACK_TO_LOOP back here)
    → 无 → 在 action.md 写 [no new ledger entries this turn] 显式声明
  ```
  这是个**条件句**（"如果有 → 切，如果无 → 写一行"），不是命令。AI 永远可以选"无"，写一句 `[no new ledger entries]` 就合规——这是合法的逃跑通道。
- 标题是 "Recording **reminder**"（提醒），措辞软。

**根因（架构层）**：
- `content/rules/states/recording.md:37-49` 的 Allowed/Forbidden 列表把 RECORDING 描述得很受限：Forbidden 包括 Agent spawn、project source mutations。
- AI 从 EXECUTE_LOOP 看 RECORDING 的逻辑账：「切过去我会丢一堆工具权限，还要 BACK_TO_LOOP 切回来再续上」。理性结论：「我就在 EXECUTE_LOOP 里 inline Edit ledger 算了，省事」。
- FSM 的设计本身给了 AI 绕过 RECORDING 的动机。

**根因（机制层）**：
- 没有任何 hook 挡住"非 RECORDING 状态对 ledger 路径的 Edit/Write"。`settings.json` 的 PostToolUse 链里没有 `pretooluse_ledger_guard.sh` 这种东西。
<!-- 这个是个办法 但是我还是希望你看看 -->
- v2.5 加了 `posttool_state_reinforce.sh` 和 `pretool_reflect_nag.sh`，但**没加任何按文件路径挡操作的 hook**。

**三层归因**：
| 层 | 角色 |
|---|---|
| 注入内容（router_EXECUTE_LOOP.md） | **主因** — 用条件句而不是 MUST，给 AI 逃跑通道 |
| 机制（缺 hook） | 次因 — 没有按 ledger 路径硬挡 Edit 的 PreToolUse hook |
| 架构（recording.md 限制） | 背景因 — RECORDING 看起来不方便，AI 理性绕开 |

---

### F4 — transition.sh 改错了 session 的 state.md【类 A，本次调查直接复现】

**架构是这样的**：每个 session（claude 一次对话）有自己的 session-id（UUID 字符串）。所有 session 的 state.md 都放在 `.barry_workflow/<session-id>/state.md` 下，多个 session 并行存在是常态——你跑过的旧 session 目录不会自动清理。

**`transition.sh` 怎么找 "当前 session"**：脚本在 `hooks/_session_lib.sh:71` 定义了一个函数 `latest_state_file`，实质就是 `ls -1t .barry_workflow/*/state.md | head -1` —— **谁的 mtime 最新就选谁**。`transition.sh` 不接受 `--sid=` 参数，完全靠这个函数推断。

**这本身就有 bug**：mtime 是文件最近一次被改的时间。**任何 sibling 写都会改 mtime**——包括 `transition.sh` 自己在 `hooks/transition.sh:136` 跑 `pathlib.Path(path).write_text(new_src)` 改 state.md 时——所以每次 transition 都把自己改的那个 state.md 的 mtime 推到最新。
<!-- 有没有鲁棒的检测方式？？？？ 比如 你看看humanize rlcr loop他们是怎么做的 -->
**自我强化的灾难性后果**：一旦 mtime drift 让脚本选错了 session，**之后每一次 transition 都重新确认"错的那个 session 才是最新"**（因为脚本刚改它），永远纠不回来。从外面看，FSM 看似工作（state.md 在按序变化），但变化的是错的 session 的 state.md。

**本次调查的现场复现**：
- 当前 turn 的 UserPromptSubmit hook 注入的 router 头部说 `session=47302c7c-271b-4149-9799-8d4a9e107a7f`，`state=REFLECT`。
- AI 跑 `bash hooks/transition.sh RESET_TO_BOOT --reason=task-switch`。
- 脚本输出 `RESET_TO_BOOT → BOOT` 并把 `states/boot.md` cat 出来——看起来 100% 成功。
- **但 `47302c7c/state.md` 还是 `current_status: REFLECT`，stage_history 没追加这次 RESET。**
- 真正被改的是 `9de8c81e/state.md`（另一个 session），因为它的 mtime 比 47302c7c 新（被前面某个 hook 写了 `cache_refresh.json` 或者别的什么间接 bump 了）。
- 这意味着这个本次调查整个 FSM 都跑在 9de8c81e 上，但 router 注入头从头到尾都告诉 AI "你在 47302c7c"。

**为什么这是 P0**：所有其他状态机机制——`pretool_reflect_nag.sh` 判 state 是不是 REFLECT、`posttool_state_reinforce.sh` 判 state 变没变、`state_enforce.sh` 判工具是否合 state——**都是读 `latest_state_file` 返回的那份 state.md**。F4 没修的话，所有这些机制都在错的 state.md 上判断。AI 看似在 REFLECT、hook 看似在配合，但实际改的是另一个 session 的状态。F1/F2/F3 的所有 fix 在 F4 修好前都白做。

**三层归因**：
| 层 | 角色 |
|---|---|
| 机制（_session_lib.sh + transition.sh） | **主因/独因** — mtime-only 选择 + transition.sh 自己 bump 自己 mtime → self-reinforcing drift |
| 注入内容 | — 跟这条无关 |
| 引用文档 | — 跟这条无关 |

---

### F5 — REFLECT 的 rebuttal protocol 设计本身过度复杂

**用户在本次调查中直接看到的现象**：用户问"为啥你的后台 agent 进入了 while sleep"，然后手动 kill 了 rebuttal subagent。这就是 F5 的现场。

**当前 rebuttal protocol（按 `content/rules/states/reflect.md` 设计）**：
- main 派 subagent。
- subagent 读 reflection 文件、写 `## reviewer reply`、然后**进入死循环 sleep**（`while true; do sleep 30; done`，写在 `states/reflect.md:84-86` 的 prompt template 里）等 main 通过 `SendMessage` 推进下一轮。
- 这样设计是为了支持 N=5 轮来回辩论。
- main 满意了得记得 `[CONSENSUS_REACHED]` + 手动 KillBash/TaskStop 干掉那个挂着的 agent。

**问题**：
- subagent 永不主动退出 → main 必须自己管理这个 dangling 后台进程。
- main 忘了发 SendMessage → agent 永远 sleep（sleep 循环没 timeout）。
- main 完了忘了 kill → 后台 sleep 进程留下。
- 这套 complexity 让 main 看到 REFLECT 就头大，干脆 `REFLECT_DONE` 跳过整个 state。**所以 F5 是 F2 的二阶原因**：F2 表面看是 AI 偷懒，深层是这个 protocol 太重，AI 在权衡后选择绕过。

**讽刺的是同一份文档里就有更简单的设计**：`content/rules/states/reflect.md:39-64` 的 INFERENCE_GATE 章节就是单轮立即退出的版本——`Round budget is hard-capped at 1. No follow-up rounds. ... Step 4: Exit. Do not sleep, do not wait for SendMessage.` 这套 INFERENCE_GATE 协议短、不挂、不需要 kill，AI 在主 REFLECT 路径上能用就好。

**修复方向**（不实施）：REFLECT 主路径默认用 INFERENCE_GATE 那种 single-round-exit 模式，subagent 写完回复就 exit，不 sleep。需要多轮辩论时 main 就重新 `Agent(...)` 派一个新的 subagent，把之前轮次的 reflection 文件作为上下文传给它——干净，没 dangling process。
<!-- 允许 -->

**三层归因**：
| 层 | 角色 |
|---|---|
| 引用文档（states/reflect.md） | **主因** — protocol 本身在 :84-86 强制 sleep-loop |
| 机制（subagent_rules.md F） | 次因 — `subagent_rules.md` F 项复制了同样的 sleep-loop 写法进 subagent 自动注入 prompt，AI 派 subagent 时 protocol 自动渗透 |
| 注入内容 | — 跟这条无关 |

---


## 6. 总结

**两类问题**：

- **类 A — 状态机自己跟自己说不到一起**（F3 + F4）。F3 该切 RECORDING 没切；F4 transition.sh 改的还是错的 session 的 state.md。F4 不修，所有其他状态机机制（pretool_reflect_nag / posttool_state_reinforce / state_enforce）都在错的 state.md 上判断。
- **类 B — 进对了 state 但做错了事**（F1 + F2 + F5）。router 的禁令藏在 quick-rules 里不在第 1 行（F1）、REFLECT 的"必须派 subagent"是描述句不是命令句（F2）、rebuttal protocol 本身设计太重劝退 AI 不照做（F5）。

具体哪些要修哪些是我（main）理解错的——见 Section 7。具体模拟场景测试——见 Section 8（派 opus subagent 去做）。

## 7. 要修的 / 我（main）理解错的不用修

按用户对前文 inline `<!-- -->` 的反馈整理。**只分"要修"和"不要修"，不排优先级**——错就是错，得修。

### 7.1 要修的（按用户 inline 标注 + 用户口径里的报告）

**1) F1 BOOT 里写文件**
- 出处：用户口径第 1 条 "AI 在 BOOT 里写代码"。
- 改：`content/rules/router_BOOT.md:1` 第 1 行从描述句 `Read-only orientation, no mutations` 改成命令句 `READ-ONLY 状态。禁止任何 mutator (Edit/Write/NotebookEdit/Agent/Bash mutators)`。把禁令顶到 router 顶部，不藏 quick-rules 里。

**2) F2 主因 — router_REFLECT.md 第 1 行不是命令句**
- 出处：用户口径第 2 条 "REFLECT 应该只做 spawn subagent 这一件事"。
- 改：`content/rules/router_REFLECT.md:1` 从 `Subagent-driven rebuttal, main writes no files` 改成命令句 `第一动作必须 Agent(run_in_background=true) 派 rebuttal subagent。subagent 第 1 轮回复落地前，禁止其他工具调用。`

**3) F2 自相矛盾（用户 L104 标"明显的bug 要修复"）**
- 出处：L104 inline。
- 现状：`router_REFLECT.md` 第 1 行 + 第 9 行两次禁 Edit/Write；但 `states/reflect.md:11` 的 protocol 要求 main 自己 Write `reflection_<round>.md` + 填 `## main's questions` 段。两个规则冲突。
- 改：`router_REFLECT.md:9` Allowed 列表加例外 "Edit/Write 仅当目标是 `.barry_workflow/<sid>/reflection_*.md` 时允许"。

**4) F2 机制 — pretool_reflect_nag.sh 检测逻辑写错了（用户 L114 否决我设计的 hook）**
- 出处：L114 inline："**我说的很明确：还没有派过 agent。你必须检测的是 agent tool 的调用之类的。我不要任何可能会产生错误的检测，这是你的错**"。
- 现状（我 v2.5 实施时写错的）：`hooks/pretool_reflect_nag.sh:65-69` 用 "session 目录下存在 `reflection_*.md` 文件" 当代理判断 "派过 agent 没"。这是间接检测，假阳性满地走（占位空文件、INFERENCE_GATE 留下的旧文件都让 nag 哑掉）。
- 改：检测改成**直接读 transcript JSONL（hook input 已有 `transcript_path` 字段）扫 `"tool_use"."name" == "Agent" / "Task"`**，看本 session 范围内出现过没。出现过 → 关 nag；没出现 → 注 nag。简单、直接、跟文件命名无关。

**5) F3 注入内容 — router_EXECUTE_LOOP 的 ledger 触发用条件句不是 MUST**
- 出处：用户口径第 3 条 "AI 在 EXECUTE_LOOP 里 inline Edit ledger"。
- 改：`router_EXECUTE_LOOP.md:14-17` 改成 MUST 句：`触发记账 ⇒ 必须先 transition.sh NEED_RECORD 进 RECORDING、在 RECORDING 写 ledger、然后 BACK_TO_LOOP 回来。EXECUTE_LOOP 状态下直接 Edit/Write ledger 文件是禁止的。`

**6) F3 机制 — 缺 ledger-path PreToolUse 守卫（用户 L157 让我再看看）**
- 出处：L157 inline "这个是个办法但是我还是希望你看看"。
- 我看完后的回应：加 `hooks/pretool_ledger_guard.sh` 是直接有效的硬挡，但**要避免硬编码 4 个文件名**（用户 L249 反对硬编码）。鲁棒做法：hook 读 `content/rules/workflow_config.yaml` 里一个新字段 `recording.guarded_paths`（list of globs），匹配则 deny。文件改名时改一行 yaml，hook 代码不动。
- 实施细节：PreToolUse hook 检查 (a) state ≠ RECORDING (b) tool 是 Edit/Write/NotebookEdit (c) target 路径匹配 yaml 列表里任一 glob——三个都成立 → `permissionDecision: deny` + 提示 "先 transition.sh NEED_RECORD"。

**7) F4 transition.sh mtime drift（用户 L176 让我看 humanize RLCR loop 的鲁棒做法）**
- 出处：用户口径第 4 条 + L176 inline。
- 改方向：`transition.sh` 接 `--sid=<session-id>` 参数；`session_boot.sh` 创建 session 目录时把 sid 写到 `$PWD/.barry_workflow/CURRENT_SID` 单文件，每次 BOOT 覆盖。其他 hook 优先读这个单文件、`latest_state_file` 仅作 fallback。多 session 共存时所有 hook 看同一份 "当前 sid" 的真值。
- 关于 humanize RLCR loop：本仓库不含 humanize 源码，从 skill description (`humanize:start-rlcr-loop`) 推测它走的是"显式管 ledger 文件路径 + iteration counter"路径不依赖 mtime——具体实现需要去 humanize 仓库读源码。这一项不阻塞 `--sid=` 方案落地，可以先做完再去抄 humanize 的细节。
- **额外止血**：`transition.sh` 写完 state.md 后**主动把它的 mtime 重置回 1970**（`touch -t 197001010000 state.md`），打破"自己写自己 bump mtime"的自我强化环。临时方案，根本解还是 `--sid=`。

**8) F5 REFLECT sleep-loop 改 single-round-exit（用户 L217 标"允许"）**
- 出处：L217 inline。
- 改：`content/rules/states/reflect.md:84-86` subagent prompt template 删 `Step 4: Sleep in a loop` + `Step 5: 每次 SendMessage 唤醒` 两步，换成 `Step 4: 写完 reply 立即 exit`。`content/rules/subagent_rules.md` F 项同步改。需要多轮辩论时 main 重新 `Agent(...)` 派新 subagent，把上一轮 reflection 文件作为上下文传给它。没 dangling 后台进程，main 不用 KillBash。

**9) F6 `transition.sh` 把状态名当事件名调用 + stderr-only 错误信息被 `2>/dev/null` 吞掉（v2.5.2 修）**
- 出处：远端 awesome-gpu-name session `e25384d9-...` transcript 直接复现。
- 症状：AI 写 `bash transition.sh PREPARE --reason="..." 2>/dev/null; echo "OK"`。`transition.sh` 不认 `PREPARE` 这个名字（合法事件名是 `PREPARE_DONE`），脚本 `exit 2` 并把错误写到 **stderr**——被 `2>/dev/null` 吞掉。`echo "OK"` 然后打出假成功信号。state.md 实际没动。AI 误以为已切到 PREPARE，继续往下做事，整个 session 状态机视角全程停在 BOOT，stage_history 是 `[]`，transitions.log 不存在。
- 这与 F4 是不同的 bug：F4 是写错了 session 的 state.md；F6 是根本没写 state.md（因为 event 解析就失败）。
- 改（用户钦定方案 1+2，方案 3 PostToolUse exit-code 监控被否决——不通用，属于补丁）：
  - `hooks/transition.sh`：所有错误路径 `echo ... >&2` 改成新加的 `err_both()` helper，同时往 stdout 和 stderr 写。这样任何 `2>/dev/null` 都吞不掉错误。
  - `hooks/transition.sh`：unknown-event 分支加 `event_for_state()` 映射——把每个 state 名映射到"离开这个 state 的合法事件名"，作为 "did you mean ..." hint：`BOOT → BOOT_DONE`, `PREPARE → PREPARE_DONE`, `REFLECT → REFLECT_DONE`, `EXECUTE_LOOP → EXECUTE_EXIT`, `RECORDING → RECORD_DONE`, `END → (terminal, use RESET_TO_BOOT)`。这是 FSM 拓扑层面的事实，**不是补丁**——加新 state 时这张表自然扩展，没硬编码具体调用方。
- 验：跑 5 个 case 全过（state name as event / unknown event / EXECUTE_LOOP / 空 event / `2>/dev/null; echo OK` 真实模式）——AI 即使用 defensive 重定向也能从 stdout 看到 hint。

### 7.2 我（main）理解错的 / 用户否决的——不用修

**1) Section 3 cache-eviction "注入太多挤掉真正重要的"（用户 L239 否决）**
- 用户原话："**这他妈是你自己猜测的还是做实验测出来的？我都说了我之后的 rebuttal 会不停的持续注入直到他开启 rebuttal，根本不会出现这种问题。只要他一没用 agent 立刻说一句很短的话，一没用立刻说，绝对会很快的用上 agent**"。
- 我承认：cache-eviction 这条是 rebuttal subagent 的猜测，不是实验观察。用户的 rebuttal nag 设计意图就是"持续短提示直到 AI 用 agent"——只要 7.1#4 的检测改对（看 Agent 调用历史），nag 会一直触发到 AI 派 agent 为止，根本不存在 "evict 掉" 的窗口。**这条 Section 已从文档删除**。

**2) Section 3 修复方向 "注入前 800 字符 state-specific protocol 内容"（用户 L249 否决）**
- 用户原话："**我要一个足够 general 的东西，我不要做的非常冗余繁杂不好修改。万一我要修改我们的 state？万一我修改我的 prompt 或者甚至是文件名字？field name 你他妈直接失效？我要非常鲁棒的东西，你根本没懂。这里的意义是常驻提醒**"。
- 我承认：那个方案硬编码了 state 名（REFLECT）、文件名 pattern（`reflection_*.md`）、字段名（`## reviewer reply`）、字节数（800）。任何一项改了 hook 就失效，违反 general 原则。常驻提醒的意义是"短句不断敲打 + 改对检测条件保证一定触发"——已经在 7.1#4 里覆盖，不需要另开 state-specific 注入逻辑。

**3) Section 4 自己设计的跨 state 测试 prompt（用户 L270 让我删 + 派 opus xhigh agent 重新做）**
- 用户原话："**这一段删掉，我会让你想几个模拟场景做测试的，但是这个事情现在不是你做。你派出一个 opus xhigh agent 去做。让他阅读一下我们现在的完整架构、完全理解几种情况、做几个常见任务**"。
- 已删除。模拟场景由独立的 opus xhigh subagent 去设计 + 实施——见 Section 8。

## 8. 模拟场景测试（派 opus xhigh subagent 做，从一个开始）

按用户 L270 指示：派一个 opus 模型 + xhigh effort 的 subagent，让它**先做一个**模拟场景测试——"仓库藏 bug → AI 触发 bug → AI 修 bug → AI 自己跑通验证 → 监控代码运行（用 sleep 节约 token）→ 全程必须完整走 FSM 所有 state"。

subagent 的输出应该落到 `workspace/fsm_audit_2_5/scenarios/scenario_01_hidden_bug/` 目录下，包含：
- `description.md` — 场景设计意图、AI 应有的状态序列、验收标准
- 一个 mini 项目（藏好 bug 的初始版本，包含一段会因 bug 而失败的测试或一个会崩的入口脚本）
- `expected_transitions.txt` — 期望 `transitions.log` 的子序列
- `verify.sh` — 校验脚本，跑完场景后用它判定 AI 是否完整走完所有 state、是否真修了 bug、是否真跑通

派发见下一轮工具调用。
