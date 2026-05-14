# Barry's Workflow v2 — 优劣分析

> 跟 `docs/implementation.html` 配套。HTML 说"做了什么 + 有没有验证"，本文说"值不值得这么做"。

## 优势

### 1. 状态机切断"跳步病" — 设计层面有效

LLM 训练数据里 `问题 → fix` 这种单跳对训得太牢，AI 默认不走中间验证。v2 在 prompt 入口注入 router + 在 policy 文件里规定 FSM 6 个 state，**把跳变成显式约束**。

不完美的执行 ≠ 完全无效：本会话 main 至少在大头任务（rebuttal / 文档 / 改 hooks）走了 BOOT→PREPARE→EXECUTE 的模板节奏，不是上来就改代码。

### 2. REFLECT rebuttal 实战可用

唯一在本会话<b>实测</b>的复杂协议。两次跑：
- 长队列调研 — 2 轮 / 12.1 分钟 / 61.5k token / 16 tool uses / agent 抓到 main 一个判断错误
- v4 P1 router 草稿 — 1 轮 / 11 分钟 / 55k token / 5 个真有用 diff

rebuttal 的 ROI：**对设计决策 / 复杂 plan 高，对简单改动严重亏损**。scenarios.html 里"简单任务跳过 pre-task REFLECT"就是承认这一点。

### 3. 模块化 + 可读

`content/rules/*.md` 拆成 10 个 policy 文件，每个 ≤ 100 行。比 v1 的 9 KB 单一巨型 inject 好维护。新增一条规则不会动到旧的。

### 4. 文档可视 + 多视角

5 个文档各管一角度：
- `README.md` 装 + 入口
- `big_picture.md` 设计哲学 + 跳步病 + 自我进化
- `scenarios.html` 理想行为 spec
- `fsm_visualization.html` 状态机视图
- `implementation.html` 实现 walk-through

新人 30 分钟看完能进入状态。v1 没这层。

### 5. 跨 LLM 适配设计已就绪

`codex_adapter.md` 列了 Claude Code ↔ Codex 的工具映射 + SendMessage poll fallback。具体实现没跑，但骨架不会锁死单一 LLM。

### 6. 自我进化路径明确

`big_picture.md` §3 描述的 patches/ 系统让 v2 可以从 bitter_lessons → 自动起草 patch → user 审 → 升 active。每个补丁都有 schema + 来源 + 证据。v1 没补丁概念，所有规则都是硬编码。

### 7. 中性化彻底

没有 cosplay 概念负担。AI 处理规则只需要关注行为本身，不用记"我是 Corporal、你是 Commander"。

---

## 劣势

### 1. 「软约束」是最大软肋

整个 v2 90% 都靠 AI<b>自律</b>走 transition.sh / 调 prepare_helper.sh。AI 不调，state.md 一直停在 BOOT，下游 hook 完全不知道。系统**没法发现 AI 跳了 state**。

具体表现：本会话 main 写了一堆 [BOOT_DONE] 这种 marker 但**从来没真调过 transition.sh**。state.md 跟实际进度脱节。

**唯一硬约束的只有 inject_router.sh**（每 turn 必然注入到 prompt）。其他全是软。

### 2. 跨 session 必断

`session_boot.sh` 每个新 sid 建新 state 文件，<b>不继承</b>旧 sid 的进度。重启 Claude → 长任务上下文全丢。

长跑队列任务（rebuttal 第一个验证的 4 大漏洞之一）在 v2 上必死。

### 3. 「实测过」的只有 1 个 hook + 1 个协议

诚实清点：
- inject_router.sh ✅ 每 turn 都跑
- REFLECT rebuttal ✅ 实测 2 次
- 其他 5 个 hooks + 8 个 policy 文件 ⚠ 全是 smoke-test，没在真任务里完整跑过

v2 实质上是 **"设计 + 占位实现"**，不是 **"成熟工作流"**。

### 4. cache_hit_map 设计有规模问题

prepare_helper.sh 列出 workspace/ 下所有 .md + sha1。长项目积累几十次 task 后，stub 会有 40+ 行，main 懒得逐行填 → 全留 UNKNOWN → 失去意义。

scaling 没考虑：每个 turn 增删 artifact 的话，sha1 频繁变也会让 cache 不断"过期"。

### 5. 4 要素 PROMPT_REINFORCED 会被无视

PREPARE 4 要素（observable / cadence / reflection / completion）几乎永远不齐。user 真实 prompt 经常就是 `"fix this bug"`，4 要素全缺 → 每个 turn 都触发 `[PROMPT_REINFORCED]` → AI 习惯化 → 跟没有一样。

### 6. anomaly 关键字脆弱

`execute_loop_audit.sh` 用 11 关键字 regex 抓 anomaly。这次扩展加了 OOM/timeout/stuck/unchanged 等 — 但 AI 写 [OBSERVE] 时不一定用这些词。规则只能<b>建议</b> AI 写啥关键字，不能强制。

### 7. /goal 依赖运行时

v2 的 stop-gating 完全靠 Claude Code 内置的 `/goal` slash command。Codex 没等价 → v2 在 Codex 上退化成"全部 advisory"。

### 8. P8 demo 没跑 → 整个 EXECUTE_LOOP 没端到端验证过

P8（Qwen + GSM8K + activation hook）是设计里唯一会真跑完整 BOOT→PREPARE→REFLECT→EXECUTE_LOOP→END 的任务。user 要求等监督才做。这意味着 EXECUTE_LOOP 失败预算、Monitor cadence、自适应监控公式 — 全没在真任务里验证。

### 9. 实现 vs 文档 不对等

`scenarios.html` 描述了 5 个理想场景的 cadence 公式（T_q/5、T_r/20→T_r/5）。**seed rules 里没明文实现这些公式**。AI 自己要建联系，类似"我看到 scenario 1 长监控 → 用那个公式" — 但 seed 也没写过 scenario 识别规则。

整个 scenarios.html 现在是<b>悬空的 spec</b>，没接到 seed 上。

### 10. 没有"系统抓 AI 偷懒"的机制

总结上面所有具体问题，最深层问题是：**没有 PostToolUse hook 检查"AI 这次工具调用前有没有写 [PLAN]"、"state 有没有按预期转换"**。要让 v2 从"设计原型"变成"成熟工作流"，必须加这层。

这是 v2.1 P11 的首要工作。

---

## 净判断

| 维度 | 评 |
|---|---|
| 思想 | ★★★★★ FSM 切跳步病、补丁层自我进化 — 设计上是对的 |
| 文档 | ★★★★ 5 视角完整、零知识可入 |
| 实现深度 | ★★ 大头是软约束 + smoke-test，真跑过的只 1-2 个 |
| 强制执行 | ★ 几乎完全靠 AI 自律 |
| Codex 兼容 | ★★ 设计就绪、未实测 |
| 跨 session | ★ 重启就断 |
| 长任务 | ★ 队列场景理想未实现 |

**用户视角**：
- 短任务 / 设计讨论 / 复杂 plan → v2 已经有用，特别是 rebuttal
- 简单代码改动 → v2 跟普通 Claude Code 区别不大（设计上承认这种该跳 REFLECT）
- 长任务 / 跨 session / 严苛监控 → v2 当前**不可靠**，需要 v2.1

**对外推广**：
- 现在不适合宣传"成熟工作流"
- 适合宣传"状态机思路 + REFLECT rebuttal 协议 + scenarios spec" 这 3 个独立可用的设计点
- 等 v2.1 P11（状态强制 hook）+ P14（demo 跑通）做完再可以叫"工作流"

---

## 修这些劣势的最小动作

| # | 劣势 | 最小修法 | 估时 |
|---|---|---|---|
| 1 | 软约束 | PostToolUse hook 校验 action.md 有 [PLAN] + state 跟工具一致 | 3h |
| 2 | 跨 session 断 | session_boot.sh 加 inherit 逻辑 | 1h |
| 3 | 只 1 个真跑过 | 跑 P8 demo + 复盘 | 4h |
| 4 | cache map 膨胀 | 加 TTL（7 天前的 artifact 不列）+ 文件大小阈值 | 1h |
| 5 | 4 要素无视 | 把 PROMPT_REINFORCED 改成 user-visible UI 提示而不是 inject 文本 | 2h |
| 6 | anomaly regex 弱 | 加"语义判 [OBSERVE]"模式 — 派轻量 subagent 判，不是 grep | 3h |
| 7 | Codex 依赖 | 实现 codex_adapter 第一版 + 跑通 | 5h |
| 8 | demo 没跑 | 见 #3 |
| 9 | scenarios 悬空 | 写 `p7_scenarios.md` 把 5 场景的识别规则 + cadence 写进 seed | 2h |
| 10 | 偷懒抓不到 | 见 #1 |

总计 ~21 小时（不含 #6 / #7 的不确定性）。
