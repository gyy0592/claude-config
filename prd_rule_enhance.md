# PRD — 声明式规则强化为操作式规则

## 背景与问题

当前 `content/rules/` 下的规则文件存在大量**声明式规则**（declarative rules）：
规则只说"要做 X"或"必须 X"，但不说**何时做、做多久、怎么确认、发现异常怎么办**。

声明式规则的根本缺陷：AI 读到"要最大化 GPU 利用率"，会回答"好的"然后什么都不做。
只有操作式规则才能驱动具体行动。

**操作式规则的四要素**：
1. **触发时机**：什么情况下执行（启动后立刻？每 X 分钟？每完成一步？）
2. **具体动作**：执行什么命令 / 检查什么输出
3. **判断标准**：什么算正常，什么算异常
4. **异常处置**：发现问题后立刻做什么

---

## 任务目标

扫描以下所有规则文件，找出其中的声明式规则，并给出操作式修复方案：

- `content/rules/1_artifacts_memory.md`
- `content/rules/2_execution_env.md`
- `content/rules/3_debug_autonomy.md`
- `content/rules/4_subagent_orchestration.md`
- `content/rules/5_autonomous_execution.md`
- `content/rules/6_user_facing_questions.md`
- `content/rules/7_crimes_penalties.md`
- `content/CLAUDE.md`（重点看 per_response、soldier_management、performance_protection 章节）

---

## 执行步骤

### Step 1 — 扫描（产出 rules_to_fix.md）

逐文件阅读，识别声明式规则。判断标准：
- ❌ 声明式："要保证 GPU 最大利用" / "必须选最快方案" / "禁止浪费资源"
- ✅ 操作式："任务启动后立刻跑 `nvidia-smi`，每 60 秒重跑一次，记录利用率到 action.md；利用率 < 70% 立刻 kill 并诊断"

每个发现写入 `rules_to_fix.md`，格式见下。

### Step 2 — 拟定修复（同写入 rules_to_fix.md）

对每条声明式规则，给出完整的操作式替换文本，包含：
- 触发时机（何时执行）
- 具体命令 / 动作
- 判断标准（正常 vs 异常阈值）
- 异常处置（立刻 kill / 立刻汇报 / 立刻修复）
- 监控频率（如适用：每 X 秒 / 每完成一步）

---

## 输出格式（rules_to_fix.md 每条目）

```
### [文件名:行号] 问题标题

**原文（声明式）**：
> 直接引用原文

**问题**：缺少 [触发时机 / 具体动作 / 判断标准 / 异常处置 / 监控频率]

**修复（操作式）**：
（完整替换文本，可直接复制粘贴到规则文件）
```

---

## 已知示例（本 PRD 起点）

**2_execution_env.md — GPU 利用率监控**

原文（声明式）："加速优先，能用 GPU 的任务必须用 GPU，不得浪费可用资源"

问题：只说"要最大利用"，不说何时检查、检查什么、多久检查一次、发现问题怎么办。

修复（操作式）：
> 任何 GPU 代码**启动后 30 秒内**必须运行 `nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader`，将结果逐行写入 soldier_action.md（标 [事实]）。之后**每 60 秒**重复一次。若任意 GPU 利用率持续 2 次采样 < 60%，立刻 kill 进程，诊断原因（DataLoader 瓶颈？单卡？代码未并行化？），修复后重启。写代码时必须加进度条（tqdm 或等价物），运行时必须观察 ETA；ETA 明显超出预期（> 2× 估算）时立刻 kill 重新检查。
