# prompt_enhancement — 4 要素检查

User prompt 经常缺隐式假设。AI 不显式补齐就会带着模糊去 EXECUTE，最后差异在 deliverable 处暴露 → 返工。本规则把 4 个要素强制显式化。

## 4 个要素

| 要素 | 意思 | 缺了会怎样 |
|---|---|---|
| **observable** | 什么具体信号证明任务推进 / 完成 | 没法在 EXECUTE 写 [OBSERVE]，AI 自己编结论 |
| **cadence** | 多久检查一次 / 什么节奏 | 长任务自旋 poll 烧 context，或者 under-poll 漏失败 |
| **reflection** | 何时派 subagent rebuttal | REFLECT 状态没触发条件，全跳掉 |
| **completion** | 什么算"做完" | AI 倾向乐观宣称 done，post-task REFLECT 没标尺 |

可调清单见 `workflow_config.yaml` `prompt_reinforce.required_elements`。

## 强制时机

**PREPARE 状态**进入后立刻做一次 4 要素检查（在写 cache_hit_map 之后、`transition.sh PREPARE_DONE` 之前）。

具体步骤：

1. main 跑 `bash ~/.claude/hooks/prepare_helper.sh` — 输出 4 要素 checklist 模板
2. 对照 user prompt + workspace/&lt;task&gt;/goal.md，每个要素打勾或填空
3. 缺任何一个 → 写一行 `[PROMPT_REINFORCED]` 到 action.md，标明缺哪个 + 提议默认值
4. 严重缺（如完全无 completion 判据）→ 派 INFERENCE_GATE 风格 1 轮 rebuttal 验默认值是否合理，或者直接问 user

## 默认值提议（缺要素时 AI 主动补）

| 缺 | 默认提议 |
|---|---|
| observable | 工具输出非空 + 期望文本 / 数字命中 |
| cadence | 短任务（&lt; 5 min）on-completion only；长任务用对应 patches/*.md cadence 公式 |
| reflection | 简单任务跳过 pre-task REFLECT；复杂 / 探索类至少 1 轮；on-anomaly 必触发 |
| completion | `goal.md` 全部 acceptance criteria 命中 + 测试通过 + 改动跑过一次 |

## 跟 INFERENCE_GATE 的关系

PROMPT_REINFORCED 跟 INFERENCE_GATE 都是「显式化隐式假设」的机制，方向不同：
- **prompt_enhancement** 在 PREPARE — 把 user prompt 里缺的<b>需求要素</b>补齐
- **INFERENCE_GATE** 在 EXECUTE / REFLECT — 把 main 想下的<b>推断结论</b>强制带证据

两者可串联：缺 completion 判据 → AI 提议默认值（这本身是 [INFERENCE]） → 触发 INFERENCE_GATE 验证 → 通过后写 `[PROMPT_REINFORCED]`。

## 不算缺的情况（避免疲劳触发）

`[PROMPT_REINFORCED]` 不是每个 user 提问都要触发。下面 3 类直接跳过：

1. **明确小任务**：「改 README 第 3 行 typo」— 4 要素都太显然，跳
2. **patches 命中**：user prompt 触发 `patches/<scenario>.md` 的 `applies_to.triggers` → 4 要素从 patch 拿默认值，无需手动检查
3. **延续上轮任务**：上一 turn 已经做过 PROMPT_REINFORCED，本 turn 在同 EXECUTE_LOOP 内 — 复用之前 4 要素结论

## 实现位置

| 位置 | 是什么 |
|---|---|
| `hooks/prepare_helper.sh` lines 33-46 | 真正的 checklist 输出文本 |
| `content/rules/workflow_config.yaml` `prompt_reinforce.required_elements` | 4 要素名字列表（可调）|
| `content/rules/states/prepare.md` step 3 | 在 PREPARE 状态里规定何时做 |
| `content/rules/prompt_enhancement.md` (this file) | <b>规则成文 + 默认值 + 跟其他机制关系</b> |
| `docs/big_picture.md` §1.5 | 用户视角的动机解释 |
