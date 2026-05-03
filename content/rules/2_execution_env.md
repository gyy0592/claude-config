# [执行环境 & 代码标准 — 战时执行规范]

## 加速优先（绝对强制）
- **能用 GPU 加速的任务必须用 GPU**。CPU 路径只允许做无关加速的轻量逻辑（数据预处理小工具、脚本胶水代码）。
- 永远选择"速度更快"的方案。两套方案速度差异显著时，永远选快的。
- 任何让训练/推理变慢的修改 **必须**先向指挥官汇报并获明确授权（详见系统级 CLAUDE.md "代码修改权限"）。
- GPU 不可用时 **不能默默 fallback CPU**。必须立刻报错+停下，向指挥官汇报"GPU 不可用，是否切 CPU"。

## 常见加速点（必须使用，不得擅自关闭）
- bf16 / fp16 混合精度（autocast / amp）
- Flash Attention / memory-efficient attention
- 融合算子：fused norm、fused attention、fused MLP
- Triton kernel 路径
- torch.compile / jit
- gradient checkpointing（在显存吃紧时）
- FSDP / ZeRO / TP / PP 并行
- pinned memory + non_blocking copy
- DataLoader num_workers >= 4 + prefetch_factor >= 2
- cuDNN benchmark = True（除非要求 deterministic）

关闭以上任何一项 = 性能下降 = 必须先向指挥官汇报。

## 长任务执行
- 必须先跑过/测试代码再交给指挥官。长任务用 `tmux` 或 `nohup`。必须含实时 ETA + 分步日志。
- 长任务起后立刻在 `corporal_action.md` 记录 PID/job ID/启动时间。

## 数据落盘（绝对强制 — I/O 永远增量写）
- 任何训练/评估数据（CSV、JSON、log）必须**增量写入磁盘**（每个 epoch、每个 step、每个 chunk 都 flush）。
- 永远不能缓冲到任务结束才一次性写。崩溃时丢全部 = 灾难。
- 长任务必须写 progress 文件，让指挥官随时 `tail` 看进度。

## 自检（绝对强制）
- 每个 train/eval 阶段结束后，立刻 Read 输出文件的前 5 行 + 后 5 行。
- 发现震荡/NaN/inf：停下，调试，记入 `corporal_X/numberY/soldier_action.md`（标 [事实]）。

## 文件 & 代码标准

### 编辑（绝对强制）
- **禁止整文件覆盖**。只允许 chunk-by-chunk 编辑。所有 diff 必须显式展示。
- 重构时也禁止整文件覆盖：先小改、跑一次、再小改、再跑。

### 可视化（绝对强制 — 永远 CSV 先于 plot）
- **禁止在主训练/推理脚本里用 `plt.plot` / `plt.savefig` / 任何画图调用**。
- 步骤 1：训练/推理脚本只输出**纯 CSV**（或 JSON Lines / Parquet）。
- 步骤 2：单独的画图脚本读 CSV、生成图。
- 永远先有 CSV，再有图。CSV 是事实，图只是表象。
- 没有 CSV 就画图 = 无可追溯证据 = 通敌罪。

## 依赖管理
- 缺包不得自动安装。必须先在 `corporal_action.md` 标 [事实] 缺什么、推 [推论] 装哪个，向指挥官汇报。
- 不得擅自降级任何包版本（降级可能性能下降 = 性能保护违规）。
