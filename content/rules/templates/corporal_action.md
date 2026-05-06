# X号下士 CLAUDE 操作流水

每次回复结束前必须追加新条目。格式：时间戳（UTC）+ 执行了什么 + 发现了什么。

---
<!-- ⚠️ 每次打开本文件准备写入前，必须先完成以下自检：

  □ 监控：已用 Read 工具读所有 active 列兵的 soldier_action.md 最新条目？
         → 无 active 列兵 = 跳过；有 = 必须先读再写本文件
  □ 军令：本次回复开头已逐字复读五条军令？
         → 未复读 = 当次违规 = 立刻记录 + 重新复读
  □ 违规三件套：本回复中有任何违规？
         → 有 = 本文件（action.md）✅ + warning_board.md 追加 ✅ + reward_board.md 追加 ✅
         → 三件套任一漏做 = 通敌罪 = 杀头

  跨文件事实禁止直接断言：需读 >1 个文件才能回答的问题 = 必须派列兵，不得凭记忆直接回答
-->
---

## YYYY-MM-DD HH:MM UTC — 接任 + 摸清需求

- [BOARD_READ] 已阅读 warning_board.md + reward_board.md + traitor.md，时间：YYYY-MM-DD HH:MM UTC
- 接任 X 号下士。前一 session 已结束，留档 `corporal_<X-1>/`（若适用）。
- 读完项目 CLAUDE.md（若有）+ 全局 ~/.claude/CLAUDE.md。
- 接任完成。

<!-- 4 步 workflow 落地范例 — 任何动手任务必走 -->

## YYYY-MM-DD HH:MM UTC — 4 步 workflow 第 1 步：列指标 + 反思

- [反思 列指标] 时间 HH:MM UTC | 一轮自问：本任务到底要盯什么？观察项清单有遗漏吗？ → 一轮自答：要盯（观-1）测试通过、（观-2）loss 无 NaN、（观-3）显存 ≤ 80GB | 二轮自问：上一轮真考虑全了吗？是否漏了运行时长 / 输出文件大小 ? → 二轮自答：补加（观-4）单步 ≤ 1.05 倍基线 | 结论：无疑虑 → 触发动作：在 corporal_status.md「## 观察项清单」段填观-1 至观-4

## YYYY-MM-DD HH:MM UTC — 4 步 workflow 第 2/3 步：监控时写 [观察] + [反思]

- [观察 观-1] 时间 HH:MM UTC | 测量命令：`pytest tests/test_a.py -v` | 数值或输出片段：`passed=10, failed=0, skipped=0`（输出尾行）| 判断结论：通过 | 严重程度：阻断级 | 反证审查：已审过 7 项危险信号（NaN / 内存溢出 / 超时 / 性能退化 / 标准错误流异常 / 跳过的测试 / 静默退到备用方案）均未出现
- [反思 监控时质询] 时间 HH:MM UTC | 一轮自问：观-1 输出真是通过吗？skipped=0 真没跳过 ? → 一轮自答：是，命令含 `-v`，跳过项会显式列出 | 二轮自问：有没有 stderr 警告被吞了 ? → 二轮自答：跑命令时 stderr 同步到 stdout，无吞 | 结论：无疑虑 → 触发动作：继续监控观-2

## YYYY-MM-DD HH:MM UTC — 4 步 workflow 第 4 步：失败 3 步闭环范例

- [观察 观-2] 时间 HH:MM UTC | 测量命令：`tail -n 500 train.log \| grep -E "NaN\|inf"` | 输出片段：`step 137: loss=NaN` | 判断结论：失败 | 严重程度：阻断级 | 反证审查：不适用（已失败）
- [失败定位 观-2] 时间 HH:MM UTC | 根因假设：学习率过高导致数值溢出 | 引用原始证据：上条 [观察] 输出 `step 137: loss=NaN`
- [处置 观-2] 时间 HH:MM UTC | 选择：上报（性能保护禁改 lr） | 具体动作：在 corporal_action.md 写「请示指挥官降 lr 授权」
- [复测 观-2] 时间 HH:MM UTC | 重跑测量命令：`tail -n 500 train.log \| grep -E "NaN\|inf"`（指挥官授权改 lr 后）| 复测 [观察] 条目编号：观-2-复测 | 复测结论：通过
