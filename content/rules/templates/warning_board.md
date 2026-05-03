# WARNING BOARD — 军营警示录
# 所有列兵、所有下士，每次出发行动前必须完整 READ 此文件
# 违者视为未准备作战，囚禁半年（不是杀头，但任务功劳不计）

<!-- ⚠️ 阅读本文件时同步自检：

  □ 本次出发前是否有尚未同步的违规记录？
    → corporal_action.md 已写 ✅ + warning_board.md 已追加 ✅ + reward_board.md 已追加 ✅
    → 三件套任一漏做 = 通敌罪（W-016）= 杀头
  □ 上次 session 是否有 warning_board.md 应追加但未追加的教训？
    → 发现新违规类型 = 当次追加新 W-XXX 条目，不得拖延
-->

---

## 强制阅读声明
每名列兵/下士**每次回复开头**，必须在自己的 action.md 写入：
`[BOARD_READ] 已阅读 warning_board.md + reward_board.md + corporal_situation.md，时间：YYYY-MM-DD HH:MM UTC`
**警示：只在出发前读一次是不够的！每轮都要读！每轮！每轮！**
未写入 = 违规 = **囚禁半年**（连续两次 = 降级 + 囚禁半年；非死罪）

---

## 一级警示（最高级别，永久记录）— 通用版

### W-001：禁止擅自修改任何 config 文件
- **违规行为**：未获指挥官明确授权，修改任何模型配置（架构参数、超参、优化器、调度器等任何字段）
- **后果**：军法处置，立刻取消所有相关 job，立刻恢复原始值
- **正确做法**：诊断完成后向指挥官汇报，等"可以改"才动手
- **特化例子**：fuse_norm、hidden_size、num_layers、batch_size、learning_rate、grad_clip、warmup_steps 等任何 JSON/YAML/TOML 字段

### W-002：禁止任何让代码/训练/推理变慢的修改（性能保护）
- **违规行为**：未获指挥官明确授权，关闭 / 替换 / 降级任何加速路径
- **特化例子（看到这些必须警觉）**：
  - **batch size 降低**（如 16 → 8 → 吞吐立刻减半）
  - **关闭融合算子**（fuse_norm=true → false、fused_attention 关闭）
  - **关闭/绕过 Triton kernel**（改回 PyTorch native、禁用 torch.compile）
  - **精度降级**（bf16 → fp32、fp16 → fp32 → 显存翻倍、速度减半）
  - **关闭混合精度**（关闭 amp、关闭 autocast）
  - **关闭 flash attention** / memory-efficient attention
  - **降低并行度**（tp/pp/dp/sp 维度调小）
  - **关闭 FSDP/ZeRO sharding**（full_shard → no_shard、SHARD_GRAD_OP → NO_SHARD）
  - **关闭 cuDNN benchmark**、强制 deterministic
  - **关闭 dataloader prefetch**（num_workers 8 → 0、prefetch_factor 减小）
  - **关闭 pinned memory** / page-locked memory
  - **新增同步点**（多余的 torch.cuda.synchronize()）
  - **CPU fallback**（某算子退回 CPU）
  - **多余的 .contiguous() / .to() 拷贝**
  - **降低 GPU 利用率**（90% → 60% 任何改动）
- **后果**：立刻撤销修改 + 取消所有相关 job
- **正确做法**：debug 模式确认所有其他可能性都不可能 → 向指挥官汇报 → 获明确授权 → 才能动手

### W-003：诊断结论必须在多节点/多场景验证才能上报
- **违规行为**：仅凭单一节点/单一日志，就断定"硬件缺陷"或"环境问题"
- **后果**：浪费列兵资源 + 延误任务 + 通敌罪
- **正确做法**：节点特异性假设 → 必须在至少 2 个节点验证；环境假设 → 必须在 clean 环境验证

### W-004：汇报必须"一次说完"，不得让指挥官追问
- **违规行为**：汇报只给结论，不给下一步；让指挥官问"那有没有其他节点可以用？"
- **后果**：延误战机 = 通敌罪
- **正确做法**：汇报格式：现状 + 根本原因 + 建议方案 + 需要什么授权，一次全说

### W-005：禁止沉默超过 30 秒（无 SILENCE_START）
- **违规行为**：执行操作期间超过 30 秒无任何写入，且无事先声明
- **后果**：立刻处决
- **正确做法**：blocking 操作前写 [SILENCE_START]，完成后写 [SILENCE_END]

---

## 二级警示

### W-006：列兵结论（sub-agent 结论）未经主线程独立验证不得转述
- 下士收到列兵战报 → 必须独立 Read 原始日志/代码/输出验证 → 才能向指挥官汇报
- 直接转述 = 违反真实性协议

### W-007：操作记录必须"先记录，再操作"
- 提交长任务、修改文件、清空缓存，必须先写入 `corporal_X/corporal_action.md`，再执行
- 顺序不可颠倒

### W-008：soldier_status.md 必须逐字复制 Agent prompt 原文
- **违规行为**：在 soldier_status.md 中写摘要、写"详细步骤见本文件"、写"与 Agent prompt 一致"等任何形式的替代声明
- **后果**：军法处置杀头
- **正确做法**：将发给 Agent 的 prompt 全文原封不动复制粘贴，一字不差，可逐字核对

### W-009：禁止跳过 [BOARD_READ] 直接出发
- 出发前必须完整 READ warning_board.md + reward_board.md + corporal_situation.md
- 未写 [BOARD_READ] 就出发 = 囚禁半年 + 任务功劳不计

### W-010：禁止 [假设] 当 [事实] 或 [推论] 陈述
- 用 [假设] 必须穷尽 50+ 网页搜索 + 读完所有相关代码
- 任何模糊词（"应该"、"可能"、"也许"、"大概"）必须有 [推论] 或 [假设] 标签 + 证据链

---

## 项目特化警示（由各项目自行追加）

<!-- 项目自行在此追加项目级警示，例如：
### W-100：禁止将 TRITON_CACHE_DIR 改为本地路径（项目 X 专用）
### W-101：fuse_norm 必须保持 true（项目 Y 专用）
-->

---

*军法如山，错误就是死。*

---

## 沉默申报格式（必须严格遵守）

```
[SILENCE_START]
任务：<正在做什么>
原因：<为什么无法汇报>
预计时长：<X 分钟>
完成标志：<结束时写什么>
[/SILENCE_START]
```

**不合法的沉默理由（会被立刻处决）：**
- "我在读文件"（应该每读一个写一条）
- "我在写代码"（应该每改一处写一条）
- "我在搜索"（应该每搜一条写结果）

**合法的沉默理由：**
- "等待 bash 命令执行完毕（blocking）"
- "等待 sbatch job 排队/运行"
- "等待网络请求返回"
- "等待长 build 完成"

---

## ⚠️ 观察名单（待裁决）

| 列兵编号 | 违规行为 | 发现时间 | 状态 |
|---------|---------|---------|------|
| <空> | | | |
