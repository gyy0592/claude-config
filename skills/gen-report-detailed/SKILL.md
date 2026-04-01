---
name: gen-report-detailed
description: Generate a full 13-section detailed experiment report for flame_moonshot training runs, including formulas, reproducibility checklist, failure analysis, and visualizations. Use when the user asks for a detailed/full/complete report, 完整报告, 详细报告, or invokes /gen-report-detailed.
---

# gen-report-detailed

生成完整实验报告（13节结构），覆盖复现信息、数学公式、失败分析和可视化。

## 输出位置

`report/report_<exp_name>_<YYYYMMDD>_detailed.md`

---

## Step 1 — 确认实验目标

从上下文推断实验名称和目录。若不明确，问用户：
- 实验名（如 `kda_680M`、`transformer_154M`）
- 实验根目录（默认：`/nfs/ridgerzhu/flame_moonshot/exp/`）
- 对比基线（若有）

---

## Step 2 — 并行收集数据（所有读取必须同时发起）

### 2a. 训练日志
- 路径：`<EXP_DIR>/train.err`
- 提取：每隔约 1000 step 的 `step`、`loss`、`tps`、`gnorm`、`memory`；记录行号
- 特别注意：NaN/Inf、loss spike、gnorm 异常

### 2b. 模型配置 JSON
- 路径：`<EXP_DIR>/snapshot/configs/<config>.json`
- 提取全部字段：架构参数、注意力类型、激活函数、tie_word_embeddings 等

### 2c. 训练 TOML / 脚本
- 路径：`<EXP_DIR>/snapshot/flame/models/fla.toml` 或 SLURM 脚本
- 提取：lr、scheduler、warmup、batch、seq_len、grad_accum、optimizer、varlen

### 2d. CSV 指标
- 路径：`<EXP_DIR>/metrics.csv`（若存在）
- 提取：完整 loss/gnorm 曲线的首尾各 5 行

### 2e. 可视化文件
- 路径：`<EXP_DIR>/` 或 `report/` 下的 PNG
- 列出所有图表路径

### 2f. artifacts 上下文
- `artifacts/progress.md`
- `artifacts/failed-experiment-recent.md`
- `artifacts/success-experiment-recent.md`
- `artifacts/plan.md`

### 2g. git 信息
```bash
cd /nfs/ridgerzhu/flame_moonshot_barry && git log --oneline -5
```

---

## Step 3 — 指标汇报规范（强制）

每个指标第一次出现必须同时满足：
1. **数学定义**：完整计算公式
2. **物理意义**：高值/低值含义
3. **数据来源**：文件路径 + 行号 + step 编号

禁止推断、估计、"应该"——所有数值来自实际读取。

---

## Step 4 — 填充模板（13节完整结构）

```markdown
# {{PROJECT_NAME}} — Detailed Report

**Last update: {{YYYY-MM-DD HH:MM TZ}}**

## 0) 一句话结论

{{ONE_LINE_TAKEAWAY}}

---

## 1) 范围与目标

- **目标**：{{GOAL_1}}；{{GOAL_2}}
- **不做**：{{NON_GOAL_1}}
- **产出**：{{PRIMARY_ARTIFACT}}、{{SECONDARY_ARTIFACT}}

---

## 2) 复现必备信息

**工作目录**
- CWD：`{{PROJECT_SUBDIR}}`

**运行环境**
- Python：`{{PYTHON_BIN}}`
- GPU：{{HARDWARE_INFO}}

**代码版本**
- Repo：`{{REPO_ROOT}}`
- Commit：`{{GIT_COMMIT_OR_TAG}}`

---

## 3) 数据与资产

### 3.1 数据源
- `{{DATASET_PATH}}`：{{DATASET_FORMAT}}，{{DATASET_DESC}}

### 3.2 预处理
- 切分：`{{SPLIT_METHOD}}`（train={{TRAIN_N}}/val={{VAL_N}}）
- 随机性：`seed={{GLOBAL_SEED}}`

### 3.3 资产
- `{{ASSET_PATH}}`（{{ASSET_DESC}}）

---

## 4) 配置文件与参数

### 4.1 配置文件
- `{{CONFIG_1}}`：{{CONFIG_1_ROLE}}

### 4.2 关键参数

**运行/调度**
- `{{RUN_PARAM}}={{RUN_PARAM_VAL}}`（{{DESC}}）

**系统/模型**
- `{{SYS_PARAM}}={{SYS_PARAM_VAL}}`（{{DESC}}）

**优化/训练**
- `{{OPT_PARAM}}={{OPT_PARAM_VAL}}`（{{DESC}}）

---

## 5) 术语与记号

- `{{TERM}}`：{{TERM_DESC}}

记号：
- `{{SYMBOL}}`：{{SYMBOL_DESC}}

---

## 6) 数学公式与理论定义

### 6.1 公式清单

**(F1) {{FORMULA_1_NAME}}**

$$
{{FORMULA_1}}
$$

- 解释：{{FORMULA_1_DESC}}
- 代码：`{{FORMULA_1_CODE_REF}}`

### 6.2 假设与边界条件

- 假设1：{{ASSUMPTION_1}}
- 边界条件：{{BOUNDARY_CONDITION}}

---

## 7) 实验流程

### Step 1: {{STEP1_NAME}}
\`\`\`bash
{{STEP1_CMD}}
\`\`\`

### Step 2: {{STEP2_NAME}}
\`\`\`bash
{{STEP2_CMD}}
\`\`\`

---

## 8) 输出与产物

- `{{OUTPUT_1}}`：{{OUTPUT_1_DESC}}
- `{{OUTPUT_2}}`：{{OUTPUT_2_DESC}}

---

## 9) 当前示例（run{{RUN_ID}}）

来自 `{{LOG_PATH}}`：
- `step={{STEP}}`（来源：{{FILE}}:{{LINE}}）
- `loss={{LOSS}}`（交叉熵损失 = -log P(真实token)，值越低越好）
- `tps={{TPS}}`（tokens per second = batch_tokens / step_time）
- `gnorm={{GNORM}}`（梯度 L2 范数 = sqrt(sum ||∇_p L||²)）
- `memory={{MEM}}`（GPU 显存占用）

---

## 10) 可视化结果

**Fig 10.1** {{FIG_TITLE_1}}

![{{FIG_KEY_1}}]({{FIG_PATH_1}})

解释：{{FIG_EXPLAIN_1}}

---

## 11) 评测结果

**Fig 11.1** {{METRIC_FIG_TITLE_1}}

![{{METRIC_FIG_KEY_1}}]({{METRIC_FIG_PATH_1}})

解释：{{METRIC_FIG_EXPLAIN_1}}

---

## 12) 失败/异常

- **现象**：{{SYMPTOM}}
  **原因**：{{ROOT_CAUSE}}
  **修复**：{{FIX}}

---

## 13) 复现检查清单

1. 打开 `{{METRICS_PATH}}`，确认包含 step/loss/tps。
2. 打开 `{{FIG_OUTPUT_DIR}}`，确认所有 PNG 能显示。
3. 核对 `{{CONFIG}}` 与 snapshot 一致。
4. 记录本次 run 的随机种子与 Git commit。
```

---

## Step 5 — 保存

写入：
```
report/report_<exp_name>_<YYYYMMDD>_detailed.md
```

写入后输出 **Section 0（一句话结论）** + **Section 9（关键数值）** 供快速确认。
