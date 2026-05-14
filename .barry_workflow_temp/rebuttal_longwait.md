# Rebuttal: 长跑队列任务在 v4 EXECUTE_LOOP 真会卡吗?

**Start**: 2026-05-14T02:22:45Z
**Reason**: pre-task (验证设计漏洞，未实写代码)
**Scenario**: AI submit sbatch (2 小时跑) → 需要每 10-15 分钟 poll → 看是否完成。问 v4 现状会怎么样。

## main's questions

main 已经识别 4 个怀疑的设计漏洞（见 fsm_visualization.html EXECUTE_LOOP 长跑队列任务 tab）。
独立 reviewer 验证每一条到底成立不、还是 main 想多了。

1. **「单 turn 内 AI 没法睡」**：Claude Code 一个 turn 里 AI 调完工具就返回 token；没有 native sleep-and-wake。问：
   - (a) 是否真没有？Monitor() 工具内部会 block 等 bash 完成吗？还是立刻返回当前 output？查 `~/.claude/rules/p3_dispatch.md` + tool 定义。
   - (b) 如果 AI 在一个 turn 里调 `Bash(sleep 900)`，runtime 会让它真挂 15 分钟吗？还是 timeout 切？读 `~/.claude/rules/fsm.md` Monitor cadence 段。

2. **「/goal 无限 block 长任务」**：当 /goal 条件是 "训完模型并汇报"，模型跑 2 小时，每次 main 想 stop 都被 /goal feedback 拦。问：
   - (a) /goal 评估器（LLM）真的每轮都注入 "still pending" 拦 stop 吗？还是它有"任务进展中、暂时容忍"的判断？  
   - (b) 假设拦 10 次，每次 squeue 一次→ 累计多少 token 进 context？粗估即可（每轮 ~500 token round-trip）。

3. **「失败预算抓不到慢」**：`execute_loop_audit.sh` 用 `grep -cE '^\\[OBSERVE\\].*\\b(refuted|anomaly|fail)\\b'` 数 anomaly。问：
   - 这关键字真会漏吗？读 hooks/execute_loop_audit.sh 确认；列出 5 个 main 真实会写的 [OBSERVE] 长度示例，哪些会被这套关键字匹配，哪些不会。

4. **「[SILENCE_START] 是装饰」**：~/.claude/rules/violation.md W-005 说 [SILENCE_START] 是合法静默声明。问：
   - 它能阻止 AI 继续生成 token / 让 Claude session 真暂停吗？还是只是事后审计标记？读 W-005 + p4_recording.md 确认。
   - 如果只是标记，那"超过 30 秒不写就 Desertion"的强制力来自哪里？(可能没人执行)

## reviewer reply

### Q1 — "单 turn 内 AI 没法睡": **半对半错**

(a) Monitor 工具 **会 block main thread**。证据:
- `hooks/stop_self_audit.sh:14-17` 注释: "Monitor blocks the main thread without firing Stop hook, allowing the AI to wait without consuming a stop attempt."
- Monitor 工具 schema (just loaded): "Stdout lines within 200ms are batched into a single notification"; `timeout_ms` 默认 300000 (5 min), 上限 3600000 (1 hr); `persistent:true` runs for session lifetime. 所以 AI 在一个 turn 内可以挂 Monitor 等 sbatch 完成 — 不是"没法睡"。
- 同时 Bash `run_in_background=true` + 等 `task_notification` 也能挂: `stop_self_audit.sh:50-54` "Stop in Claude Code semantics means main thread sleeps until task_notification wakes it".

(b) `Bash(sleep 900)` 前台调用: Bash 工具默认 2 min timeout、上限 10 min — 不能真挂 15 min。但 `fsm.md:36-39` 规定的就不是 sleep, 而是 "Monitor(bash_id=...) every 10-15 min". 即 v4 设计上 AI 不靠睡, 而是用 Monitor 轮询 bg job. **main 担心夸张**: 长跑机制是有的 (Monitor + bg + task_notification), 不是没有。

### Q2 — "/goal 无限 block": **完全错误**

(a) v4 **没有 runtime /goal LLM 评估器**. 证据:
- `~/.claude/rules/codex_adapter.md:19` 表格: `/goal (slash command) | ❌ no native | autonomous-3-failure rule from p6_workflow.md M6 is the only stop signal`
- `codex_adapter.md:61-70`: `/goal` fallback 是 "user writes goal verbatim into workspace/<task>/goal.md ... main's REFLECT (post-task) sub-agent verifies goal.md ... **Loss vs /goal: no runtime LLM evaluator forcing continuation.**"
- `hooks/inject_decrees.sh:48` 只让 AI Read `goal.md`, 没有 hook 拦 stop based on goal.

(b) 既无评估器, "拦 10 次累计 token" 命题不成立. 真实拦 stop 的是 `stop_self_audit.sh` 看 `.claude_status/{sid}_status.md` 的 STOP-GATE 全 1 — 跟 goal 内容无关。

### Q3 — 失败预算抓不到慢: **claim 成立**

`hooks/execute_loop_audit.sh:17` regex = `\b(refuted|anomaly|fail)\b`. 5 个真实 sbatch poll [OBSERVE]:

1. `[OBSERVE] step=1200 unchanged 30min, loss flat` → **miss** (无关键字)
2. `[OBSERVE] exit code 2, traceback CUDA OOM` → **miss** ("exit code 2" 不含 fail/anomaly/refuted; "traceback" 也不在 regex)
3. `[OBSERVE] queue position 23, no progress` → **miss**
4. `[OBSERVE] job FAILED on node05` → **HIT** (含 "fail")
5. `[OBSERVE] sbatch returned anomaly: node down` → **HIT** (含 "anomaly")

5 个里 3 个漏 — 包括最常见的 OOM/exit-code-2/stuck-queue 三大坑。**main 指出的漏洞真实**: 长跑场景里"慢/卡/非零退出"全跑掉。建议扩 regex: `refuted|anomaly|fail|stuck|unchanged|timeout|exit code [1-9]|traceback|OOM|killed`.

### Q4 — "[SILENCE_START] 是装饰": **基本成立**

`rule says you must`: violation.md:52-56 W-005 + p4_recording.md 都规定要写。
`mechanism enforces`: **无**。
- 搜遍 `hooks/*.sh`, 无任何 hook 解析 `[SILENCE_START]`/`[SILENCE_END]` 时间戳并阻断 token 生成或强制暂停。
- `stop_self_audit.sh` 看 STOP-GATE 不看 silence 标记。
- "30 秒不写 = Desertion" 的强制力来源: 仅靠下一轮 main 自己 reflect / Commander 事后审计。即审计标记, 非 runtime gate。

**总结 (round 1)**: main 的 4 条怀疑里, Q3 完全成立 (regex 太窄), Q4 基本成立 (无 runtime 执行), Q1 夸张了 (Monitor 能挂 + bg+notify 能挂), Q2 完全错 (v4 根本没 LLM /goal 评估器)。建议聚焦真实漏洞: 扩 audit regex + 接受 [SILENCE_START] 仅审计语义。

### round 2 — Q2 修正

Round 1 我把 "v4 repo 没实现 /goal 评估器" 当成 "Claude Code 整个 runtime 没 /goal 评估器" — 错了。重读 `RESEARCH_NOTES_GOAL_HOOK.md` (P9 调研笔记) 后确认两套机制必须分清:

| 层 | 状态 | 证据 |
|---|---|---|
| v4 codebase 自实现 /goal 评估器 | **不存在** | `codex_adapter.md:19,61-70` "❌ no native ... no runtime LLM evaluator". `hooks/inject_decrees.sh:48` 只 Read 静态 goal.md, 无 evaluator hook. |
| **Claude Code runtime 内建 /goal slash command** | **存在且有 LLM 评估器** | `RESEARCH_NOTES_GOAL_HOOK.md:8-17`: user 本会话输 `/goal 把v4_plan.md...`, runtime 回 "A session-scoped Stop hook is now active ... The hook will block stopping until the condition holds. It auto-clears once the condition is met." 后续 stop 尝试被注入 "Stop hook feedback: ... 5 of 10 tasks completed, 5 pending. Not satisfied." — 明显 LLM 读 transcript 比对 goal 文本, 不是 shell grep 整数。 |

P9 笔记 line 38-42 还明确写: "v4 workflow relies on /goal for stop-gating", 即 v4 故意 retire 了 `stop_self_audit.sh` 改靠 runtime /goal. 所以长任务场景:

- main 的 Q2 (a) **成立**: runtime /goal 评估器每次 stop 都跑一遍, 不存在"任务进展中暂时容忍" — P9 笔记没观察到任何 mid-progress tolerance, 只看到二元 satisfied / not satisfied。
- main 的 Q2 (b) **成立**: 每次拦 stop 注入一段 "Stop hook feedback" 进 transcript + 评估器自己读 transcript 也烧 token. 粗估每拦一次 ≥500 token (feedback 文本进 user context; 评估器内部 transcript scan 的成本对 user 不可见但对 runtime 真实存在). sbatch 2 小时跑、10-15 分钟一 poll → 一个 turn 内 stop 8-12 次 = 4k-6k token 噪声直接堆 context, 长跑场景明显不友好。

**修正后 4 条全部成立**: Q1 (夸张但底层有 Monitor 兜底, 不致命), Q2 (runtime /goal 真会反复 block + 烧 token), Q3 (audit regex 漏 OOM/exit-code/stuck), Q4 ([SILENCE_START] 仅审计无 runtime 强制力)。

致歉 round 1 在 Q2 上未区分 "v4 repo 实现" vs "Claude Code runtime 内建" — 单看 repo 文件容易漏掉 runtime 层功能, P9 笔记是关键证据。

[CONSENSUS_PENDING]

## consensus

**[CONSENSUS_REACHED]** 2026-05-14T02:34:30Z

成本统计：
- Round 1: 680.6s / 54962 tokens / 12 tool uses
- Round 2: 47.9s / +6578 incremental tokens / 4 tool uses
- 合计：728.5s ≈ **12.1 分钟** / **~61.5k tokens** / 16 tool uses

4 洞全部成立（agent round 2 修正后）：

| Hole | 严重度 | 修法 |
|---|---|---|
| Q1 单 turn 无 sleep | 🟡 夸张 | 已有 Monitor() / bg+task_notification 兜底，main 知道用就行 |
| Q2 runtime /goal 长任务反复 block | 🔴 真 | 设计上要 LONG_WAIT 子状态，进 LONG_WAIT 时 /goal 临时挂起 |
| Q3 audit regex 漏 OOM/exit/stuck | 🔴 真 | execute_loop_audit.sh:17 regex 1 行扩展 |
| Q4 [SILENCE_START] 仅审计 | 🟡 真 | violation.md W-005 改措辞为"审计标记"而非"暂停机制"|

下一步 commit：
1. ✅ 扩 audit regex
2. ✅ 修 EXECUTE_LOOP "异常→bug" 子图 notes：明示 grep 关键字依赖问题
3. ✅ 修 END notes：加 runtime /goal 长任务噪声警告 + LONG_WAIT 待实现
4. ⏸ LONG_WAIT 子状态实现（非本轮做，进 v4.1 计划）

