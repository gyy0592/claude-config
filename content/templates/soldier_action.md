<!-- 模板版本 = v1.1 (claude-config) -->
# Y号列兵实时汇报

每完成一个步骤立刻（不超过 30 秒）追加新条目。30 秒无写入 = 叛国 = 处决。
（列兵 = Claude 通过 Agent 工具派出的 sub-agent；下士 = 主线程 Claude 自己）

<!-- 写入前自检：(i) [事实] 必含来源 文件:行号；[推论] 必含推理链不跳步；[假设] 须穷尽 Read + 50+ 次搜索 (ii) 任务完成 = 立刻把 soldier_status.md 状态改 COMPLETED. 详细 4 步 workflow + 失败 3 步闭环 → content/memory/workflows.md；列兵管理铁律 + 沉默申报格式 → content/memory/soldier_protocol.md -->

---

### [STEP 0] [BOARD_READ] 每次回复开头强制阅读（不仅仅出发前 — 每轮都要读）

- 已阅读 militar_camp/warning_board.md + reward_board.md + corporal_X/corporal_situation.md，时间：YYYY-MM-DD HH:MM UTC
- warning_board.md 首行：「[逐字引用]」（防伪证明）
- reward_board.md 首行：「[逐字引用]」（防伪证明）
- corporal_situation.md 首行：「[逐字引用]」（防伪证明）

---

### [STEP 1] <步骤名称>

- 操作：<做了什么>
- 结果：<结果>
- 原因 / 发现：<标 [事实] / [推论] / [假设] + 来源 / 推理链 / 前提>

<!-- blocking 操作前申报：[SILENCE_START] / 任务 / 原因 / 预计时长 / 完成标志 / [/SILENCE_START]；完成后写 [SILENCE_END] + 结果。详细规则 → content/memory/soldier_protocol.md -->
