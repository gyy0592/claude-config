# plan_recording — Recording 子系统现状 + 改造计划

> Scope: 让 AI 在该写盘的时候被 hook 强制提醒，不再「全靠自觉」。
> Out of scope: subagent FSM (P31) / patches auto-load (P32) / 路径变量化 (P40)。

---

## 1. 应写文件清单 + 现状覆盖

| # | 文件 | 写入时机 | 当前提醒机制 | 状态 |
|---|---|---|---|---|
| 1 | `.barry_workflow/<sid>/action.md` `[BOARD_READ]` | 每次 reply 开头 | `inject_router.sh` 注入 ROUTER 提醒 | ✅ |
| 2 | `.barry_workflow/<sid>/action.md` `[PLAN]` | 每次 mutator 前 | `pretooluse_short_nudge.sh` **只** catch Edit | ⚠️ |
| 3 | `.barry_workflow/<sid>/action.md` `[OBSERVE]` | mutator 返回后 | `execute_loop_audit.sh` 事后 audit，不主动催 | ❌ |
| 4 | `workspace/attempts_ledger.md` (ATT-N) | turn 收尾 | 无 hook，靠 stop-gate 自觉 | ❌ |
| 5 | `workspace/bitter_lessons.md` (L-N) | 碰项目技术坑 | 无 | ❌ |
| 6 | `workspace/successful_fixes.md` (FIX-N) | fix 经 3-Q 验证 | 无 | ❌ |
| 7 | `workspace/rule_violations.md` (W-N) | AI 项目内行为错 | 无 | ❌ |
| 8 | repo `content/templates/global_rules/violation.md` → `~/.claude/rules/violation.md` | 跨项目 AI 违规 | 无 hook 防 AI 直接 Edit 部署副本 | ❌ |
| 9 | repo `content/templates/global_rules/lessons.md` → `~/.claude/rules/lessons.md` | 跨项目智慧 | 同上 | ❌ |
| 10 | `workspace/<task>/goal.md` | user 控制，main 只读 | — | — |
| 11 | `.barry_workflow/<sid>/state.md` | `transition.sh` 自动 | 全自动 | ✅ |

覆盖率：**3/9 文件有 hook 级提醒**；其余 6 类靠 AI 自觉。

## 2. 关键漏洞

- **A. `[PLAN]` nudge 太窄** — 只 catch Edit。Bash 长命令 / Write / Agent spawn 都漏。
- **B. `[OBSERVE]` 完全没 reactive hook** — PostToolUse 当前没挂任何东西，AI 调完工具直接叙述结论。
- **C. 事件驱动是空中楼阁** — bitter_lessons / successful_fixes / rule_violations / 全局 violation / 全局 lessons 这 5 类，规则文档说「碰到坑/fix work/犯错/学到智慧才该写」，但**事件发生时没任何 hook 提醒 AI**，长上下文里几乎必漏。
- **D. 全局 violation/lessons 双源容易写错** — AI 经常直接 Edit `~/.claude/rules/*.md`，被下次 deploy 覆盖丢失。
- **E. session_boot 只 seed 不 remind** — workspace/ 下 4 个 ledger 创建后没主动告诉 AI「这些文件存在，记得 grep `task:` 你自己历史」。

## 3. 改造方案：引入 RECORDING state（B + C 组合）

> 抛弃之前 F4-F11 那套「分散 hook + nudge 计数」的复杂设计——绕远了。
> 改用单一手段：**新增 RECORDING state**，让 AI 专注做记账，由 FSM 结构本身保证「不漏记」。
> F2 (PLAN) + F3 (OBSERVE) 仍单独保留——那两个是 pre/post tool 的纪律，与 state 无关。

### 3.1 当前 FSM（事实）

```
BOOT --BOOT_DONE--> PREPARE --PREPARE_DONE--> REFLECT --REFLECT_DONE--> EXECUTE_LOOP
                                                ^                            |
                                                └──── EXECUTE_EXIT ──────────┘

任意 state --RESET_TO_BOOT--> BOOT
```

（文档里之前提过 END，但 `transition.sh` 里没事件落地——doc-only fiction，本计划顺手把它落地。）

### 3.2 新 FSM（目标）

```
BOOT → PREPARE → REFLECT → EXECUTE_LOOP
                   ↑↓             ↓
                   └── (loop) ────┘
                   ↓ (EXECUTE_EXIT 强制经过)
                 RECORDING
                   ↓ RECORD_DONE
                  END
```

新增/改动：
- **RECORDING state**：专做 ledger 记账，allowed 仅 append-only writes to `workspace/*.md` + 全局 `content/templates/global_rules/*.md`
- **END state**：会话收尾（之前是 fiction，现在落实）
- **强制出口（B）**：`EXECUTE_EXIT` 不再回 REFLECT，而是 → RECORDING；从 RECORDING 才能 `RECORD_DONE` → END
- **软提醒（C）**：`router_REFLECT.md` / `router_EXECUTE_LOOP.md` 末尾加一句「如果本轮已碰坑/犯错/fix work，可随时 `transition.sh NEED_RECORD` 进 RECORDING」，允许中途主动进

### 3.3 新事件表（改 `hooks/transition.sh`）

| 当前 state | 事件 | 新 state | 备注 |
|---|---|---|---|
| BOOT | BOOT_DONE | PREPARE | 不变 |
| PREPARE | PREPARE_DONE | REFLECT | 不变 |
| REFLECT | REFLECT_DONE | EXECUTE_LOOP | 不变 |
| EXECUTE_LOOP | EXECUTE_EXIT | **RECORDING** | **改向**（原 → REFLECT，现 → RECORDING）|
| REFLECT | **NEED_RECORD** | **RECORDING** | 新增（软提醒主动入）|
| EXECUTE_LOOP | **NEED_RECORD** | **RECORDING** | 新增 |
| **RECORDING** | **RECORD_DONE** | **END** | 新增 |
| **RECORDING** | **BACK_TO_LOOP** | **EXECUTE_LOOP** | 新增（中途进的情况，记完接着干）|
| 任意 | RESET_TO_BOOT | BOOT | 不变 |

state.md 需多一个字段 `prev_status: <state>`，让 RECORDING `BACK_TO_LOOP` 知道回哪。

### 3.4 router_RECORDING.md 内容骨架

```
[ROUTER · state=RECORDING] You are in RECORDING. Focus: append entries to ledgers, no project work.

→ Full spec: cat ~/.claude/rules/states/recording.md
→ Allowed: append-only Write/Edit to workspace/*.md + content/templates/global_rules/*.md + .barry_workflow/<sid>/action.md
→ Forbidden: project source mutations / Agent spawn / Bash mutators

Self-check (answer all 4 before transition):
  1. 本会话有无项目技术坑（lib 不兼容 / 配置组合 / 硬件怪癖）? → workspace/bitter_lessons.md L-N
  2. 本会话有无确认成功的 fix（3-Q 通过）? → workspace/successful_fixes.md FIX-N
  3. 本会话 AI 自己有无违反规则（跳 dispatch / 漏 PLAN / record-skip）? → workspace/rule_violations.md W-N
  4. 上述 1-3 是否有跨项目意义? → 加写 content/templates/global_rules/{lessons,violation}.md
  
End-of-turn ATT: workspace/attempts_ledger.md ATT-N（本 turn 干了啥的一行 intent log）

Advance:
  - `transition.sh BACK_TO_LOOP` → return to EXECUTE_LOOP (mid-task record then continue)
  - `transition.sh RECORD_DONE`  → END (final ledger before session close)
```

### 3.4b 软提醒（C）注入位置 —— 常驻提示在哪

在 `router_REFLECT.md` 和 `router_EXECUTE_LOOP.md` **末尾**各加一段（每 turn UserPromptSubmit 注入时都会出现）：

```
Recording reminder (always-on in this state):
  本轮有无任何记账值得做？— 项目技术坑 / 成功 fix / AI 自身违规 / 跨项目智慧
  → 有 → `bash ~/.claude/hooks/transition.sh NEED_RECORD --reason="<one-line>"` 进 RECORDING
  → 无 → 在 action.md 写一行 `[no new ledger entries this turn]` 显式声明
```

这就是「常驻提醒」机制——零额外 hook 成本，与现有 `[ROUTER]` 注入同流程。
AI 在 EXECUTE_LOOP 或 REFLECT 的**每一轮 reply 开头**都会看到这段，自然会主动判断要不要切。

### 3.5 router_END.md（落实）

```
[ROUTER · state=END] Session closing. Read-only + final summary.

→ Spec: cat ~/.claude/rules/states/end.md
→ Allowed: Read + SendMessage final summary
→ Forbidden: any mutator

Pre-close checklist:
  - workspace/*.md 本次新增条目都已落盘?
  - .barry_workflow/<sid>/action.md 末尾有 [no new ledger entries] 或 ATT-N?
```

### 3.6 改动清单

| 文件 | 改什么 |
|---|---|
| `hooks/transition.sh` | 加 4 个事件 + `prev_status` 字段读写 |
| `hooks/_session_lib.sh` | 加 read/write `prev_status` 工具函数 |
| `content/rules/router_RECORDING.md` | 新建（见 §3.4）|
| `content/rules/router_END.md` | 改写（见 §3.5）—— 当前内容只列 allowed/forbidden，没 pre-close checklist |
| `content/rules/router_REFLECT.md` | 末尾加 NEED_RECORD 提示行 |
| `content/rules/router_EXECUTE_LOOP.md` | 同上 |
| `content/rules/states/recording.md` | 新建—— full spec |
| `content/rules/states/end.md` | 修订—— 加 pre-close checklist |
| `content/CLAUDE.md` | FSM 图加 RECORDING + END 节点 |
| `content/rules/fsm.md` (if exists) | 同步 |
| `docs/system_overview.md` | §FSM 段落同步 |

### 3.7 还要的两个独立 hook（不进 FSM）

仍保留之前的：
- **F2** 扩展 `pretooluse_short_nudge.sh` 覆盖所有 mutator → 修清单 #2
- **F3** 新 `posttooluse_observe_nudge.sh` → 修清单 #3

这两个跟 state 无关（是工具调用前后纪律），不该塞进 RECORDING state。

---


## 4. 实施顺序（新方案）

| 批次 | 内容 | 解决清单 # |
|---|---|---|
| **批 1** | 新 FSM：RECORDING + END state 全套（§3.3-§3.6 一次完成）| #4, #5, #6, #7, #8, #9 + 落实 END |
| **批 2** | F2 + F3：PreToolUse mutator 全覆盖 + PostToolUse OBSERVE nudge | #2, #3 |
| **批 3** | F10：session_boot 首屏 ledger pointers（可选，低优先）| E |
| **批 4** | F11：4-module reflection 规范化（可选，低优先）| 4-module 定义 |

每批落地后：
- 同步改 `content/rules/recording.md`
- 同步改 `set_claude.sh` 部署（如有新 hook 注册）
- 同步改 `docs/system_overview.md` §FSM + §Recording

---

## 5. 风险 / 已知坑

- L-017: bash heredoc + `set -u` 注意 `${...}` 转义，写新 hook 时复用 `_session_lib.sh` 而不是新起 heredoc。
- L-019: 不在 hook 输出的中文里嵌 ASCII 双引号。
- 过度 nudge 会噪：所有 nudge 都走 stderr + 短句（≤ 80 字），不堵 tool 调用主流。
- PostToolUse 在 PreToolUse hard-block 时不会触发——P51 设计需考虑这一点（不需要纠错路径）。
