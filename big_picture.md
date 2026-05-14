# big_picture — barry-workflow 设计本质

## 1. 本质

**一个状态控制器**。让 AI 从一个状态走到另一个状态，每个状态约束他「现在只能干这件事」。仅此而已。

状态机骨架（FSM）= 不变量。

```
BOOT → PREPARE → REFLECT ↔ EXECUTE_LOOP → END
```

骨架不解决"具体怎么干"，只解决"现在该处于哪个阶段、不许跳出"。

## 2. 当前 workflow = 通用初始模板（Seed）

写在 `~/.claude/rules/*.md` + `content/rules/*.md` 里的所有内容（policy / FSM 细节 / cadence 默认值 / rebuttal N=5 / [PLAN]/[OBSERVE] 形式）—— 都是**初始最佳猜测**，按"对大多数任务管用"做的。

**它不会 cover 所有事情**。譬如：
- 长监控任务：seed 里 cadence 写"5-60 min 用 Monitor"是粗糙的，实战需要 T_q/5、T_r/20 自适应
- 找 bug：seed 里写"列 facts/inferences/assumptions"，但有些 bug 类（性能差、并发竞态）seed 没覆盖
- 探索性研究：seed 没说必须 2 轮 rebuttal 才稳

→ 缺失 / 错估的部分靠**补丁**补。

## 3. 补丁系统

### 3.1 补丁两种来源

| 来源 | 触发 | 例子 |
|---|---|---|
| **人工**（user 发现 seed 不够） | user 观察到 AI 把这事做砸 → 写补丁 | "长监控用 T_q/5 → T_r/20 → T_r/5" |
| **自动**（AI 自己经历后写） | AI 在 EXECUTE_LOOP 真踩坑 → REFLECT post-task 总结 → 自动写补丁 | "GSM8K batch=24 在 H100 永远 OOM，下次直接降 batch=8" |

### 3.2 补丁存储 — 统一位置

```
workspace/<task>/patches/         ← 项目级（跟 bitter_lessons.md 并列）
~/.claude/rules/patches/          ← 全局（跨项目，所有 session 自动加载）
```

不允许散写。所有补丁集中两个地方，避免一团乱麻。

### 3.3 补丁结构（强制 schema）

每个补丁一个文件 `patch_<id>.md`：

```markdown
---
id: P-042
created: 2026-05-14T10:30:00Z
source: human | auto-from-bitter-lessons | auto-from-violation
scope: global | project
applies_to:
  state: [EXECUTE_LOOP, REFLECT]      # 在哪些 state 生效
  scenario: long_monitor              # 来自 scenarios.html 的场景 key（可空）
  triggers:                           # 何时启用此补丁
    - tool: Bash
      cmd_regex: "sbatch|squeue"
    - file_glob: "**/train*.py"
priority: 100                         # 多个补丁冲突时大的覆盖小的
status: active | deprecated | superseded-by:P-099
---

## what
（一句话：这个补丁干啥）

## why
（事故 / 观察 / 用户决策的证据链）

## how
（具体规则，可执行 / 可对照）

## examples
（before / after，至少 1 对）
```

### 3.4 补丁的加载与生效

- 每个 session BOOT 后，由 hook 扫两个 patches/ 目录，把 status=active 的注入 router 末尾
- router 显示"近期相关补丁 N 条 → 详见 patches/index.md"
- AI 在 PREPARE 时，按 `applies_to` 过滤出当前任务可能命中的补丁，逐条 Read
- 补丁优先级高于 seed rules（priority > rules baseline）

### 3.5 自动写补丁的判据

| 情况 | 自动写到哪 | 然后呢 |
|---|---|---|
| EXECUTE_LOOP 出 anomaly 后 fix 成功 | `bitter_lessons.md` 一条 | 若 ≥ 3 个 task 写出同类 bitter_lesson → 提示 user 升级为 patch |
| REFLECT post-task 发现 seed 规则不准 | `rule_violations.md` 一条 + auto 起草 `patches/draft_<id>.md` | user 审 → 转 active |
| 长监控任务结束统计 cadence 实际效果 | `workspace/<task>/patches/` 直接落地 | 若效果好 → user 提到 global patches |

→ AI 不是无脑写补丁。补丁有"草稿态"→ user 审核 → 升 active 的流程。

## 4. 状态机自我进化

```
seed rules (不变) + 补丁 N 条 → AI 行为 → 新踩坑 → 草稿补丁 → user 审 → 补丁 N+1 条 → ...
```

**关键性质**：
1. **可逆**：随时能 deprecate 一个补丁回滚，不动 seed
2. **可审计**：每个补丁有来源 + 证据 + 时间，能追溯为什么这么干
3. **可迁移**：global patches 跟着 set_claude.sh 部署到任何项目
4. **可超越**：seed 之后能长成"远超 seed 复杂度"的工作流，但骨架（FSM）不变

**反模式（不允许）**：
- 直接改 seed rules 来"修复"具体场景 → 污染骨架，长期不可控
- 补丁不写 `applies_to` → 无限制全局生效，互相冲突
- 补丁不写 `why` → 后人不知道能不能删

## 5. 类比

把 v4 想成 **Linux 内核 + 补丁包**：
- FSM 状态机 = 内核 syscall 接口（很久不动）
- seed rules = 默认配置 (`/etc/default/*`)
- patches/ = 用户自定义配置 + 第三方模块
- bitter_lessons.md / rule_violations.md = 日志，看完写成 patch 才有长期价值

或者 **机器学习**：
- 状态机 = 模型架构
- seed rules = pretrained weights
- patches = fine-tuning 数据
- 自动写补丁 = active learning loop

## 6. 当前缺什么 — TODO

| 项 | 状态 |
|---|---|
| FSM 骨架 + 6 个 state | ✅ v4 P1-P10 完成 |
| seed rules（policy 8 个 + fsm.md） | ✅ v4 P2 完成 |
| `scenarios.html` 通用场景库 | ✅ 这轮做完 |
| `patches/` 目录 + schema | ❌ **未做** |
| 补丁加载 hook（BOOT 时扫 + router 注入） | ❌ **未做** |
| 自动写补丁 — bitter_lessons → 草稿 patch 升级 | ❌ **未做** |
| user 审补丁的 UI / 命令 | ❌ **未做** |

→ 下一阶段（v4.1 或 v5）的主要工作是把 patch 系统建起来，让 v4 真正具备自我进化能力。
