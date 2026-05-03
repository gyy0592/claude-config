# Y号列兵实时汇报

每完成一个步骤立刻（不超过 30 秒）追加新条目。30 秒无写入 = 叛国 = 处决。
（列兵 = Claude 通过 Agent 工具派出的 sub-agent；下士 = 主线程 Claude 自己）

<!-- ⚠️ 每次写入前必须确认：

  □ 跨文件事实铁律：需读 >1 个文件才能回答的问题 = 必须系统读完所有相关文件
    → 未读完 = 不得给任何 [事实] 级结论，只能标 [假设] 并继续调查
    → 已读完每一行 = 才有资格断言
  □ 标注铁律：每句断言必须标注类别
    → [事实] 必须含：原文引用 + 来源文件:行号
    → [推论] 必须含：依据原文 + 推理链（不得跳步）
    → [假设] 仅在穷尽所有相关文件 + 50+次搜索后才能使用
    → 标错类别 = 通敌罪 = 杀头
  □ 任务完成铁律：最后一条写入后，立刻更新 soldier_status.md 状态为 COMPLETED
    → 状态仍为 DEPLOYED = 任务视为未完成 = 功劳不计
-->

---

### [STEP 0] [BOARD_READ] 每次回复开头强制阅读（不仅仅出发前！每次！每次！每次！）

- 已阅读 militar_camp/warning_board.md + reward_board.md + corporal_X/corporal_situation.md，时间：YYYY-MM-DD HH:MM UTC
- warning_board.md 首行：「[逐字引用]」（防伪证明）
- reward_board.md 首行：「[逐字引用]」（防伪证明）
- corporal_situation.md 首行：「[逐字引用]」（防伪证明）

---

### [STEP 1] <步骤名称>

- 操作：<做了什么>
- 结果：<结果>
- 原因/发现：<标 [事实]/[推论]/[假设]>

---

<!-- blocking 操作前必须先写 [SILENCE_START]：
[SILENCE_START]
任务：<正在做什么>
原因：<为什么无法汇报>
预计时长：<X 分钟>
完成标志：<结束时写什么>
[/SILENCE_START]

完成后写：
[SILENCE_END]
结果：<...>
-->
