---
name: gen-report-concise
description: Generate a concise experiment report for flame_moonshot training runs. Use this skill when the user asks to write a report, summarize an experiment, document results, 写报告, 整理实验, 总结实验结果, or invokes /gen-report or /gen-report-concise.
---

# gen-report-concise

生成精简实验报告（4节结构），自动从日志/配置/CSV 收集数据填充。

## 输出位置

`report/report_<exp_name>_<YYYYMMDD>.md`（保存在当前 repo 的 `report/` 目录）

---

## Step 1 — 确认实验目标

从上下文推断实验名称和目录。若不明确，问用户：
- 实验名（如 `kda_680M`、`transformer_154M`）
- 实验根目录（默认：`/nfs/ridgerzhu/flame_moonshot/exp/`）

---

## Step 2 — 并行收集数据（所有读取必须同时发起）

一次性并行读取以下内容：

### 2a. 训练日志
- 路径：`<EXP_DIR>/train.err`（或 `logs/` 下对应的 `.out`/`.err`）
- 提取：最新 `step`、`loss`、`tps`、`gnorm`、`memory`
- **每个指标必须记录：来源文件路径 + 行号 + step 编号**

### 2b. 模型配置
- 路径：`<EXP_DIR>/snapshot/configs/<config>.json`（优先）或 `configs/<config>.json`
- 提取：`hidden_size`、`num_layers`、`num_heads`、`vocab_size`、模型类型

### 2c. 训练配置
- 路径：`<EXP_DIR>/snapshot/flame/models/fla.toml` 或训练脚本
- 提取：`lr`、`batch_size`、`seq_len`、`grad_accum`、`total_tokens`、优化器

### 2d. CSV 指标（若存在）
- 路径：`<EXP_DIR>/metrics.csv` 或 `<EXP_DIR>/train_metrics.csv`
- 提取：loss 曲线最后5行

### 2e. artifacts 上下文
- 读取 `artifacts/progress.md`（了解实验背景）
- 读取 `artifacts/success-experiment-recent.md`（了解对比基线）

---

## Step 3 — 指标汇报规范（强制）

填入每个指标时必须满足：
1. **数学定义**：给出计算公式（如 `tps = batch_tokens / step_time`）
2. **物理意义**：说明高/低值含义
3. **数据来源**：文件路径 + 行号 + step 编号

禁止写"约"、"大约"、"应该"——所有数值必须来自实际读取的文件。

---

## Step 4 — 填充模板

使用以下结构生成报告（严格替换 `{{}}` 占位符，删除未使用的块）：

```markdown
# {{PROJECT_NAME}} — Concise Report

**Last update: {{YYYY-MM-DD HH:MM TZ}}**

---

## 0) 核心结论 (Takeaway)

在 **{{SYSTEM_NAME}}** 上，**{{CORE_METHOD}}** 相比 **{{BASELINE}}** 带来 **{{KEY_IMPROVEMENT}}**，代价为 **{{KNOWN_TRADEOFF}}**。

---

## 1) 目标与核心逻辑 (Motivation & Logic)

**目标**：{{GOAL}}

**核心假设**：{{HYPOTHESIS}}（即：{{WHY_IT_SHOULD_WORK}}）

**核心公式**（仅列支撑本实验的 1-2 个）：

**(F1) {{FORMULA_1_NAME}}**

$$
{{FORMULA_1}}
$$

直觉：{{FORMULA_1_INTUITION}}（高值 → {{HIGH_MEANING}}；低值 → {{LOW_MEANING}}）

---

## 2) 复现与执行 (Reproducibility)

**代码与环境**
- Repo / CWD：`{{REPO_ROOT}}`
- Commit：`{{GIT_COMMIT}}`

**数据与配置**
- Dataset：`{{DATASET_PATH}}`
- Config：`{{CONFIG_PATH}}`

**执行与产出**

\`\`\`bash
# 运行命令
{{RUN_CMD}}

# 核心输出目录（logs / CSV / PNG）
OUTPUT_DIR="{{OUTPUT_DIR}}"
\`\`\`

---

## 3) 实验结果与深度分析 (Results & AI Insight)

### 3.1 {{PHENOMENON_1_NAME}}

**数据溯源**：`{{CSV_OR_LOG_PATH_1}}`，第 {{LINE_NUM}} 行，step={{STEP_NUM}}

**AI 深度分析**

- **趋势拆解**：{{TREND_ANALYSIS_1}}
- **因果归因**：{{CAUSAL_ANALYSIS_1}}
- **异常诊断**：{{ANOMALY_1}}（若无异常则删去此行）

---

## 4) 综合结论与 Trade-off

| 维度 | {{METHOD}} | {{BASELINE}} | Delta |
|------|-----------|-------------|-------|
| {{METRIC_1}} | {{VAL_M1}} | {{VAL_B1}} | {{DELTA_1}} |
| {{METRIC_2}} | {{VAL_M2}} | {{VAL_B2}} | {{DELTA_2}} |
| {{METRIC_3}} | {{VAL_M3}} | {{VAL_B3}} | {{DELTA_3}} |

**结论**：{{FINAL_CONCLUSION}}

**下一步**：{{NEXT_STEP}}
```

---

## Step 5 — 保存

将填充完毕的报告写入：
```
report/report_<exp_name>_<YYYYMMDD>.md
```

写入后告知用户路径，并输出 **0) 核心结论** 内容供快速确认。
