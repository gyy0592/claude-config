# [执行环境 & 代码标准 — 战时执行规范]

## 任务开始前：资源侦察（绝对强制）

**任何代码/训练/推理任务开始前，必须先做资源侦察，再做方案设计**。不做侦察 = 盲目执行 = 失职罪。

### 侦察步骤（顺序执行）

**Step 1：探明可用资源**
```bash
# GPU 数量和型号
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader 2>/dev/null || echo "无 GPU"
# CPU 核心数
nproc
# 内存
free -h | head -2
```

**Step 2：判断任务瓶颈**
- 「本任务的瓶颈是什么？」GPU 显存？CPU 核心？I/O？内存？
- 瓶颈决定并行策略，不是"越多越好"。
- 示例：
  - 任务需要 4 张卡，机器有 8 张 → 用 4 张，不抢占其他用户的 4 张
  - 任务是 CPU 密集型 + 32 核机器 → `multiprocessing.Pool(32)` 或 `--nproc_per_node 32`
  - 任务 I/O 受限 + SSD → 增加 `num_workers`，不是增加 GPU

**Step 3：设计并行方案**
- 提出至少一个并行优化假设：`[推论] 当前方案单进程跑，可改为 N 进程并行，预计加速 X 倍`
- 验证方案不超过实际资源限制

**Step 4：向指挥官汇报**
格式：`[侦察报告] GPU: N张 × 型号（显存），CPU: N核，内存: XGB。任务瓶颈: ___。建议方案: ___。`

---

## 加速优先（绝对强制）
- **能用 GPU 加速的任务必须用 GPU**。CPU 路径只允许做无关加速的轻量逻辑（数据预处理小工具、脚本胶水代码）。
- 永远选择"速度更快"的方案。两套方案速度差异显著时，永远选快的。
- **不得浪费可用资源**：如果机器有 8 卡但方案只用 1 卡，必须解释为什么不并行，或改为并行方案。
- **不得超占实际瓶颈**：任务瓶颈是 8 卡，不得请求 16 卡（占用他人资源 = 失职罪）。
- 任何让训练/推理变慢的修改 **必须**先向指挥官汇报并获明确授权（详见系统级 CLAUDE.md "代码修改权限"）。
- GPU 不可用时 **不能默默 fallback CPU**。必须立刻报错+停下，向指挥官汇报"GPU 不可用，是否切 CPU"。

### 并行方案清单（按场景）

| 场景 | 正确做法 | 错误做法 |
|------|---------|---------|
| 多 GPU 训练 | `torchrun --nproc_per_node=<实际GPU数>` | 硬编码 nproc=1 |
| 数据预处理 | `multiprocessing.Pool(nproc())` 或 `dask` | 单进程 for 循环 |
| 评估多个 checkpoint | 按 GPU 数分批并行，`subprocess` 并发 | 串行逐个跑 |
| DataLoader | `num_workers=min(cpu_count, 8)` | `num_workers=0` |
| 文件 I/O 密集 | 异步 I/O (`aiofiles`) 或多线程 | 同步逐文件读 |

---

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

---

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
