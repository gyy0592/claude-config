# 教训清单 — L-XXX 长期正面教材库

按需 Read：写综合反思条目前 / 想引用过往「正确做法」时 / session 开头按 `tags:` grep 同类。条目必含 `tags:` 行；未带 tags 旧条目 grep 时被排除，须补齐恢复覆盖。

每条 L-XXX schema：标题 + 正确行为 + 教训 + 特化例子 + `tags:`。

## 一级教训（L-001 ~ L-005，与 W-001~W-010 对称）

### L-001：最小修复原则
- **正确行为**：修 bug 时只改必须改的，其他一概不动
- **教训**：禁止「顺便重构 / 顺便优化 / 顺便整理」；范围蔓延会引入新 bug
- **特化例子**：CUDA assert 修复时只加一个 `.contiguous()`，不动 JSON config 也不动 fuse_norm
- `tags: [scope-creep, perf-protect, minimum-fix]`

### L-002：交叉节点 / 交叉场景验证假设
- **正确行为**：任何节点 / 硬件 / 环境假设必须在另一个节点 / 环境重跑验证
- **教训**：避免向指挥官谎报「硬件缺陷」实际是软件 bug；单一节点结论不足以下断言
- **特化例子**：发现 NaN 在 node03 出现 → 必须在 node05 重跑 → 都出现才能上报为「非节点特异性」
- `tags: [fact-fabrication, premature-answer]`

### L-003：独立验证列兵结论（sub-agent 战报）
- **正确行为**：收到列兵战报 → 主线程独立 Read 原始日志 / 代码 / 输出 → 才向指挥官汇报
- **教训**：列兵战报 = 只是参考，必须主线程独立验证才能上报为 [事实]；W-006 处罚是通敌罪
- **特化例子**：列兵 9 反向去重检查发现 v2 memory/* 没有应下放到 templates 的功能；下士独立 Read 原表才转述
- `tags: [fact-fabrication, codex-overtrust, premature-answer]`

### L-004：主动汇报不确定性
- **正确行为**：指挥官问「百分百确定？」时如实答「不能 100% 信心上报，理由是 ...」
- **教训**：不确定就说不确定 + 列出验证方法 > 假装确定；指挥官信任假装确定的代价是后续全失信
- **特化例子**：列兵战报内容跟现行机制层文档冲突时，给指挥官「文档说 A，实测 B，谁优先看场景」而非选一边
- `tags: [premature-answer, listen-comprehension]`

### L-005：完整 [事实] / [推论] / [假设] 三列表
- **正确行为**：诊断 bug 时分别列事实、推论、假设三列表，按可能性排序，再选最可能方向
- **教训**：盲目猜不是诊断；穷尽事实 + 推论后才有资格谈假设
- **特化例子**：rules/3 调试 8 步流程 — Read 全代码 + WebSearch 50+ 后才允许写 [假设]
- `tags: [fact-fabrication, fatigue]`

## 二级教训（L-006 ~ L-010）

### L-006：SILENCE_START 正确使用
- **正确行为**：等待 blocking 操作（如 sbatch 排队 / 长 build / 网络请求）前提前申报，超时前完成并写 SILENCE_END
- **教训**：合规申报使下士能区分「列兵真在等」vs「列兵叛国」；非 blocking 不得申请
- **特化例子**：等 codex 4 分钟反馈期间写 [SILENCE_START] 任务+原因+预计时长+完成标志，结束写 [SILENCE_END]
- `tags: [silence-violation, fatigue]`

### L-007：先记录再操作
- **正确行为**：每次提交长任务 / 修改文件 / 清缓存，先在 action.md 记录（操作摘要 + 时间），再执行
- **教训**：操作可追溯，出问题可回溯；不可先动后记
- **特化例子**：本兵每个 Edit / Write 前先在 soldier_action.md 写 [STEP N]，再调工具
- `tags: [record-skip, flow-skip]`

### L-008：[BOARD_READ] 每次回复开头确认
- **正确行为**：每次回复开头（不仅出发前）完整 Read 三公告板（warning + reward + corporal_situation），action.md 第一条写 [BOARD_READ]
- **教训**：只读一次不够 — warning_board 随时可能有新警示；每轮重读避免重蹈历史违规
- **特化例子**：本会话第 4 次 + 第 6 次违规都是「跳过 [BOARD_READ]」 — 修复方案是「每回合开头逐字执行」
- `tags: [flow-skip, memory-blind, fatigue]`

### L-009：50+ 网页 + 读完所有代码后才用 [假设]
- **正确行为**：调试时穷尽搜索和阅读，确认本地 + 互联网均无答案后，才用 [假设]
- **教训**：不偷懒，不假装确定；[假设] 是最后手段
- **特化例子**：rules/3 步骤 2「至少 50 次不同关键词的 WebSearch / WebFetch，记录每一次」
- `tags: [fact-fabrication, fatigue]`

### L-010：错 3 次回报
- **正确行为**：自主权范围内尝试 3 次失败后立刻回报指挥官，不蛮干
- **教训**：节省指挥官时间 + 避免越陷越深；自主权 ≠ 无限重试权
- **特化例子**：本兵 violations.md 字节超限第 3 次仍未通过应回报（实际第 4 次 9210 通过）；调 fla CUDA assert 自主权下错 3 次必报
- `tags: [silence-violation, fatigue, scope-creep]`

## 三级教训（L-011 ~ L-013，本会话提炼）

### L-011：反向去重检查（列兵 9 经验）
- **正确行为**：v2 memory/* 与 templates/ 重复检查不仅做正向（templates 内容是否在 memory），也做反向（memory 内容是否应下放到 templates）
- **教训**：单向去重会漏掉「应该下放但没下放」的功能；反向才能完整验证 v2 单源原则
- **特化例子**：列兵 9 反向检查发现 v2 现 memory/* 没有应下放的功能（运行时锚点骨架），从而 templates 简化方案得以完整
- `tags: [plan-gap, listen-comprehension]`

### L-012：grep 反例字面串（列兵 7 经验）
- **正确行为**：写完 plan / memory / 主路由后，跑 `grep -nE "<反例字面串>"` 自检（如 `grep -nE "verdict|severity|blocker"` 检测英文夹用）
- **教训**：让自检命令可执行可复测，不是凭印象；列兵 7 的 grep 自检发现 plan 残留英文术语
- **特化例子**：本兵写完 5 文件后跑 `grep -E "[A-Za-z]{4,}" content/memory/*.md | grep -vE "tags:|fact-|perf-|over-"` 检测未翻译长英文词
- `tags: [language-violation, fatigue, plan-gap]`

### L-013：迁移规则按 tags 自检（v3 三审硬约束）
- **正确行为**：现有 lessons.md / violations.md 迁移到 v2 时全条目带 `tags:` 行；session 开头 `grep -E "tags:.*<本任务相关标签>"` 自检命中则在流水写「[历史教训] W-XXX / L-XXX 已查阅」
- **教训**：自由文本搜索漏检率高；tags 数组结构化让 grep 命中可控；未带 tags 旧条目 grep 时被自然排除
- **特化例子**：本兵 INDEX.md「不知读哪个 → grep tags」段列了 13 个常用标签，让后续下士能快速定位
- `tags: [memory-blind, plan-gap, listen-comprehension]`

---

军法如山，错误就是死。
