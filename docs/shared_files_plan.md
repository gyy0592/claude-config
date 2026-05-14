# shared_files_plan.md — workspace ledger 共享方案

**状态**：草案（user 审过即实施，先 v2，过测再合 main）
**作者**：main
**起因**：当前 4 个项目级 ledger 在每个 `workspace/<task>/` 各一份，跨任务无法复用经验。期望仓库共享一份。

---

## 1. 当前 vs 目标

### 当前

```
$PWD/
└── workspace/
    ├── task_a/
    │   ├── goal.md
    │   ├── bitter_lessons.md          ← per-task
    │   ├── successful_fixes.md         ← per-task
    │   ├── attempts_ledger.md          ← per-task
    │   └── rule_violations.md          ← per-task
    └── task_b/
        ├── goal.md
        └── （同上 4 个 ledger）
```

问题：在 task_a 踩过的坑，task_b 的新 session 不会自动读到。每个 task ledger 内容互相隔离。

### 目标

```
$PWD/
└── workspace/
    ├── bitter_lessons.md              ← 仓库共享（新）
    ├── successful_fixes.md             ← 仓库共享
    ├── attempts_ledger.md              ← 仓库共享
    ├── rule_violations.md              ← 仓库共享
    ├── task_a/
    │   └── goal.md                      ← 仍然 per-task
    └── task_b/
        └── goal.md
```

`goal.md` 留在 `workspace/<task>/`（每任务目标不同）。
4 个 ledger 提升到 `workspace/` 共享。每条 entry 加 `task:` 字段做内部分桶。

---

## 2. 设计决策（待 user 确认）

| 决策点 | 推荐 | 备选 |
|---|---|---|
| 共享 ledger 放在哪 | `$PWD/workspace/` | `$PWD/` 根目录 |
| 区分任务的字段 | 每条 entry 加 `task: <name>` 字段（与 `tags:` 并列） | 只靠 `tags:` |
| 老 per-task ledger 迁移 | 不强制并；新条目走新位置，老的当历史 | 写脚本 / 手动 |
| 发布通道 | v2 测过再合 main | 直接 main |

---

## 3. 牵连面（27 个文件，113 处引用）

### 运行时（行为可能变）

| 文件 | 改动 |
|---|---|
| `scripts/new_task.sh` | 只拷 `goal.md` 到 task 子目录；如 `workspace/*.md` 4 个 ledger 不存在则**首次**从 `content/templates/` 铺一次（idempotent） |
| `hooks/prepare_helper.sh` | **不改**——已 glob `workspace/*/*.md` + `workspace/*.md` 两层 |
| `hooks/session_boot.sh` | **不改**——只查 `workspace/` 目录是否存在 |
| `hooks/state_enforce.sh` / `pretooluse_short_nudge.sh` / `execute_loop_audit.sh` | **不改**——不写死 ledger 路径 |

### 规则文档（注入到 AI 上下文，必须改）

| 文件 | 改动量 |
|---|---|
| `content/CLAUDE.md` | "Common project artifacts" 段 + "Recording" 表 4 行 |
| `content/rules/recording.md` | Recording 表 4 行 + 区分说明的路径 |
| `content/rules/states/boot.md` | BOOT 读 `workspace/<task>/{bitter,successful}` → `workspace/` |
| `content/rules/states/end.md` | END 追加路径表 4 行 |
| `content/rules/states/prepare.md` / `execute.md` / `reflect.md` | 各 1 处 `rule_violations.md` 路径 |
| `content/rules/router_END.md` | `workspace/<task>/*.md ledgers` → `workspace/*.md ledgers` |
| `content/rules/codex_adapter.md` / `patches/bug_debug.md` | 各 1 处 |
| `content/templates/{bitter_lessons,attempts_ledger,successful_fixes}.md` | 顶部注释路径示例 |
| `content/templates/README.md` / `global_rules/violation.md` | 各 1 处 |

### 用户文档

| 文件 | 改动 |
|---|---|
| `README.md` / `README.en.md` | quickstart 注释 + §5 文件结构表 |

### 内部 docs（v2 限定，不发 main）

`docs/{big_picture, problem_discussion, pros_cons, RESEARCH_NOTES_GOAL_HOOK, v2.1_plan, v3_plan, v4_plan, p8_e2e_notes}.md` + `v2_plan.md` — 描述性引用，照实改路径。

### 不动

- `viewer/data/b68e44cd-*/...` — 历史 session 快照
- `~/.claude/rules/{violation,lessons}.md` — 全局跨项目，本次不动
- `.barry_workflow/<sid>/{state,action,transitions,reflection}.md` — per-session，不动
- `skills/` — 完全正交

---

## 4. 关键边界 / 边角情况

| 问题 | 方案 |
|---|---|
| **A. 跨任务过滤** —— task_b BOOT 时如何区分 task_a 的条目是否相关？ | 每条 entry 加 `task: <name>` + `tags:`。BOOT 阶段 AI grep 当前 `<task>` 名 OR 共同 tags |
| **B. 老 per-task ledger 怎么办** | 不并；新条目从新位置开始；老 `workspace/<task>/*.md` 当历史不删 |
| **C. `new_task.sh` 首次行为** | 创建 `workspace/<name>/goal.md`；如 `workspace/*.md` 4 个 ledger 不存在则首次铺模板（之后任务不会覆盖）|
| **D. 全局 `violation.md` / `lessons.md`** | 不动——本次只动项目级 |

---

## 5. 实施步骤（user 拍板后执行）

1. 改 `scripts/new_task.sh` 行为（首次铺共享 ledger / 后续只建 goal.md）
2. 改 9 处规则文档（CLAUDE.md / recording.md / 5 个 states/*.md / router_END.md / codex_adapter.md / patches/bug_debug.md）
3. 改 3 个 templates 顶部注释
4. 改 README.md / README.en.md 两处
5. 改内部 docs/ 9 个文件
6. 远程 set_claude.sh 部署 + smoke test：用 new_task.sh 起一个新任务，确认 ledger 出现在 `workspace/` 而非 `workspace/<task>/`
7. push v2，user 看过后合 main

---

## 6. 待 user 回答的 4 个问题

1. 共享 ledger 放 `workspace/` 还是 `$PWD/` 根目录？（推荐 `workspace/`）
2. 每条 entry 加 `task:` 字段？还是只靠 `tags:`？（推荐加）
3. 老 per-task ledger 迁移：不并 / 写脚本 / 手动？（推荐不并）
4. 发布通道：v2 测好再合 main？（推荐是）

回答完我就动手。
