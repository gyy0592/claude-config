# v2 Plan — Claude-Only Refactor (Commander 审阅文档)

**版本**：v2-Eng-claude-hook  
**生成时间**：2026-05-12  
**作用域**：仅 Claude 侧（`content/CLAUDE.md` + hooks + `~/.claude/`）—— Codex 侧 (`content/AGENTS.md` / `set_codex.sh` / 派生 symlink) **本计划不动**，留待后续单独迭代。  
**依据文档**：`corporal_understanding.md`（10 主题）+ `pipeline_visualization_v3.html`（v3 state-init 已固化设计）+ `RESEARCH_NOTES_HOOKS.md`（hook 周期事实表）

---

## 0. 总目标 — 一句话

把"AI 必须朗读军令 + 手抄派遣模板"的脆弱机制，换成 **Hook 自动注入 + 记录文件分层** 的可靠机制，让以下 7 个长上下文崩溃场景都不再失守：
1. AI 不朗读军令 / 跳过身份
2. AI 自己读多文件 / 跳派遣
3. AI 写"我反思了"但不真写
4. 派遣后没用 CronCreate / Monitor 工具
5. 子代理读不到 CLAUDE.md
6. 长 agent 链中部 Decrees 消失
7. [INFERENCE] 滥用 / 修复不验证

---

## 1. 现状快照（read 完确认的事实）

### 1.1 当前文件清单（不算 v3 设计中要新增的）

| 路径 | 行数 | 用途 |
|------|------|------|
| `content/CLAUDE.md` | 203 行 | 启动注入主路由（被 `~/.claude/CLAUDE.md` symlink 引用）|
| `content/AGENTS.md` | ~143 行 | Codex 用（**本计划不动**）|
| `content/memory/INDEX.md` | 25 行 | 4 文件触发表 |
| `content/memory/violations.md` | ~1000+ 行 | W-XXX + tags 全局违规库 |
| `content/memory/lessons.md` | ~1000+ 行 | L-XXX + tags 全局经验库 |
| `content/memory/workflows.md` | ~300 行 | G1~G16 性能保护 + Debug 8-step + [OBSERVE]/[REFLECT] 格式 |
| `content/memory/soldier_protocol.md` | 162 行 | 派遣 4-step + Iron Rules A-G + 沉默格式 |
| `content/templates/corporal_status.md` | 63 行 | 5 段观察清单（含 Section 4 [INFERENCE] 自检）|
| `content/templates/corporal_action.md` | 26 行 | 行动日志骨架 |
| `content/templates/corporal_situation.md` | 20 行 | 战况骨架 |
| `content/templates/soldier_status.md` | 30 行 | Private 状态骨架 |
| `content/templates/soldier_action.md` | 26 行 | Private 行动日志 |
| `content/templates/warning_board.md` | 33 行 | 公告板 ⚠️（v2 要**删**）|
| `content/templates/reward_board.md` | 21 行 | 奖励板 ⚠️（v2 要**删**）|
| `content/templates/traitor.md` | 71 行 | 叛徒档案 ⚠️（v2 要**删**）|
| `content/templates/README.md` | 55 行 | 模板说明 |
| `init_corporal.sh` | 75 行 | 入营脚本（创建 militar_camp + 公告板 + corporal_X）|
| `init_soldier.sh` | ~50 行 | 派遣脚本 |
| `set_claude.sh` | ~400 行 | 部署脚本（CLAUDE.md → ~/.claude/）|
| `hooks/` | 不存在 | ⚠️ v2 要**新建** |

### 1.2 当前 Hook 状态

[FACT] `~/.claude/settings.json` 当前**没有** UserPromptSubmit / PreToolUse / PostToolUse hook。本仓库 git reset 到 `1cdabf6` 之后，今天加过的 hook 配置已被还原成 reset 前状态（**未验证此处，需要确认**）。

⚠️ **执行前需要验证**：`cat ~/.claude/settings.json` 看 hooks 部分是否为空，避免覆盖意外配置。

### 1.3 当前朗读机制散落位置（要删的）

| 位置 | 内容 |
|------|------|
| `content/CLAUDE.md:1-4` | 顶部 Most Important Rule banner（5x "MUST RECITE..."）|
| `content/CLAUDE.md:88` | 4-Step Opening 的 Step 1 |
| `content/CLAUDE.md:100` | "Missing any one of 1/2/3 steps" |
| `content/CLAUDE.md:104` | Pre-check (0) 朗读自检 |
| `content/CLAUDE.md:108-110` | Key Decrees 标题旁 |
| `content/CLAUDE.md:114` | 论文 arXiv:2406.15981 引用（支持"放开头朗读"的依据）|
| `content/CLAUDE.md:116` | Decree 1 内文"first word must be Decree" |
| `content/CLAUDE.md:134` | Identity section 朗读支撑 |
| `content/CLAUDE.md:189-194` | End Restatement 三连 |
| `content/CLAUDE.md:202` | Final reminder 四大元规则 |
| `content/memory/soldier_protocol.md:80` | Private 4-step 第 1 步朗读 |

---

## 2. 目标架构（v2 完成后）

### 2.1 文件分层

```
~/.claude/
  ├── CLAUDE.md          ← symlink to /home/yguo173/Programs/claude-config/CLAUDE.md (deployed)
  ├── settings.json      ← contains hook registrations
  └── rules/             ← NEW directory; auto-loaded by Claude on every session
      ├── violation.md   ← MOVED from content/memory/violations.md (AI rule violations, cross-project)
      └── lessons.md     ← MOVED from content/memory/lessons.md (cross-project behavior wisdom)

/home/yguo173/Programs/claude-config/        (repo root)
  ├── CLAUDE.md          ← deployed copy of content/CLAUDE.md (path-substituted)
  ├── content/
  │   ├── CLAUDE.md      ← AUTHORITATIVE source (this gets surgical edits)
  │   ├── AGENTS.md      ← Codex, UNCHANGED in v2
  │   ├── memory/
  │   │   ├── INDEX.md         ← UPDATED for new ledger system
  │   │   ├── workflows.md     ← MINOR updates (retest 3-Q + INFERENCE evidence)
  │   │   ├── soldier_protocol.md ← Iron Rule C update + dispatch template update
  │   │   ├── violations.md    ← DELETED (migrated to ~/.claude/rules/)
  │   │   └── lessons.md       ← DELETED (migrated to ~/.claude/rules/)
  │   └── templates/
  │       ├── corporal_status.md     ← MINOR (Section 4 INFERENCE upgrade for 2nd reflection)
  │       ├── corporal_action.md     ← MINOR (add note about new ledger entries)
  │       ├── corporal_situation.md  ← UNCHANGED
  │       ├── soldier_status.md      ← UNCHANGED
  │       ├── soldier_action.md      ← UNCHANGED
  │       ├── README.md              ← UPDATED for new file list
  │       ├── warning_board.md       ← DELETED
  │       ├── reward_board.md        ← DELETED
  │       ├── traitor.md             ← DELETED
  │       ├── operation_log.md       ← NEW
  │       ├── attempts_ledger.md     ← NEW
  │       ├── bitter_lessons.md      ← NEW
  │       └── successful_fixes.md    ← NEW
  ├── hooks/                          ← NEW directory
  │   ├── inject_decrees.sh           ← NEW (UserPromptSubmit + PostToolUse:Agent)
  │   └── inject_decrees_to_subagent.sh  ← NEW (PreToolUse:Agent)
  ├── init_corporal.sh   ← UPDATED (new templates, delete old, migration check)
  ├── init_soldier.sh    ← UNCHANGED
  ├── set_claude.sh      ← UPDATED (deploy hooks + create ~/.claude/rules/ + register hooks in settings.json)
  └── set_codex.sh       ← UNCHANGED (v2 not touching codex)

<project>/militar_camp/                    (project-level)
  ├── operation_log.md      ← NEW (from template)
  ├── attempts_ledger.md    ← NEW (from template)
  ├── bitter_lessons.md     ← NEW (from template)
  ├── successful_fixes.md   ← NEW (from template)
  ├── README.md             ← UNCHANGED
  └── corporal_X/           ← UNCHANGED (status / action / situation)
  └── (REMOVED: warning_board.md, reward_board.md, traitor.md)
```

### 2.2 Hook 注入策略

| Hook | matcher | Action | Cap |
|------|---------|--------|-----|
| `UserPromptSubmit` | (any) | `hooks/inject_decrees.sh` | ~4.5 KB |
| `PostToolUse` | `Agent` | `hooks/inject_decrees.sh` | ~4.5 KB |
| `PreToolUse` | `Agent` | `hooks/inject_decrees_to_subagent.sh` | ~6 KB (含 Iron Rules) |

**触发覆盖**：
- 用户消息 → UserPromptSubmit ✅
- Cron 定时 → UserPromptSubmit ✅（已搜索验证：cron 触发 UserPromptSubmit + Stop）
- 主线程派遣后等子代理 → PostToolUse:Agent 在子代理返回时给主线程上下文重注 Decrees ✅
- 子代理初始 prompt → PreToolUse:Agent 直接改 `tool_input.prompt` 前置 Decrees + Iron Rules ✅

---

## 3. 修改清单（按依赖顺序）

按以下顺序执行可保证每一步 self-contained，不会留下中间断裂状态：

### 阶段 A：准备（无破坏性）

#### A1. 新建 hooks 目录 + 两个脚本
- `mkdir -p hooks/`
- 写 `hooks/inject_decrees.sh`：完整 6 条军令 verbatim + 顶/底暴力重复块 + Prompt Reinforcement 4-item kit 节
- 写 `hooks/inject_decrees_to_subagent.sh`：用 jq 解析 stdin JSON，前置注入 Decrees + Iron Rules A-G 到 `tool_input.prompt`，输出修改后的 JSON
- `chmod +x hooks/*.sh`
- **测试**：`echo '{}' | bash hooks/inject_decrees.sh` 输出非空且包含 6 条军令；`bash -n hooks/*.sh` 语法检查通过

#### A2. 新建 4 个项目级模板
- `content/templates/operation_log.md`（操作流水）
- `content/templates/attempts_ledger.md`（尝试账本）
- `content/templates/bitter_lessons.md`（失败 efforts 归档）
- `content/templates/successful_fixes.md`（最终成功修复）
- 每个文件含表头 + schema 注释 + 1 个示例条目

每个模板的 schema（详细字段在 §5）：
- `operation_log.md` → `[OP-N] time | who | what | why | reverted? | next?`
- `attempts_ledger.md` → `[ATT-N] time | target_bug | hypothesis | what tried | commit | before_obs | after_obs | verdict (worked/failed/partial/wrong-direction) | next`
- `bitter_lessons.md` → `WRONG WAY N: target / tried / commit / before-after / why failed / cost / abandon criteria`
- `successful_fixes.md` → `FIX N: bug / final approach / commit / before-after / why this worked / generalizable lesson`

### 阶段 B：迁移全局规则文件

#### B1. 把 `content/memory/violations.md` 内容拆分
- 大部分内容 → `~/.claude/rules/violation.md`（new global location）
- 但暂时**保留** `content/memory/violations.md` 文件，加个 deprecation 头：「已迁移至 ~/.claude/rules/violation.md；本文件保留 1 release cycle 兼容；新条目请写到全局位置」
- 等所有项目脚本/INDEX 切换完成后，下个 release 真删

#### B2. 把 `content/memory/lessons.md` 同样处理
- 内容 → `~/.claude/rules/lessons.md`
- 原文件保留 deprecation 头

#### B3. set_claude.sh 加入新部署步骤
- 创建 `~/.claude/rules/` 目录（如不存在）
- 把 `content/memory/violations.md` → `~/.claude/rules/violation.md`（首次 deploy 时复制；重复部署做差异合并）
- 把 `content/memory/lessons.md` → `~/.claude/rules/lessons.md`
- 部署 `hooks/*.sh` 到 `~/.claude/hooks/`（或软链）
- 在 `~/.claude/settings.json` 用 Python 幂等合并三个 hook 注册

### 阶段 C：删除项目级公告板模板

#### C1. 删 3 个模板
- `rm content/templates/warning_board.md`
- `rm content/templates/reward_board.md`
- `rm content/templates/traitor.md`

#### C2. 更新 `init_corporal.sh`
- 移除 `cp $TEMPLATE_DIR/{warning_board,reward_board,traitor}.md $CAMP_DIR/` 三行
- 新增 4 行：`cp $TEMPLATE_DIR/{operation_log,attempts_ledger,bitter_lessons,successful_fixes}.md $CAMP_DIR/`
- 加入 **migration 检测**：如果 `$CAMP_DIR` 已存在但缺少新模板文件 → 补创建（不动 corporal_X/ 子目录）
- 加入旧文件**警告**（不删，让 Commander 看到）：如果 `$CAMP_DIR/warning_board.md` 还存在 → echo "⚠️ 旧 warning_board.md 仍存在，内容已被 violation.md (~/.claude/rules/) + bitter_lessons.md 取代，可手动删除"

### 阶段 D：CLAUDE.md 主路由手术（最关键）

#### D1. 删除朗读相关（11 处，§1.3 列出的）

具体 diff 见 §6。删完之后 4-Step Opening 变 3-Step。

#### D2. 升级 REFLECT-A 为 6 行表格

`content/CLAUDE.md:122-126` 现有 [REFLECT-A] 文字描述，改为 markdown 表格 schema（6 行 D1-D6）。

#### D3. 升级 Decree 2 加入 effort log + 2nd reflection 要求

`content/CLAUDE.md:117` Decree 2 文末追加两小节：
- (a) Effort log 内嵌格式
- (b) 2nd meta-reflection 要求

#### D4. 升级 Decree 6 retest 加入 3 问

`content/CLAUDE.md:121` Decree 6 retest 部分追加三问 (a)/(b)/(c)。

#### D5. 升级 Decree 3 / M4 监控加入 Monitor tool 验证

`content/CLAUDE.md:118` Decree 3 监控铁律 (c) 后面追加：「CronCreate 之后必须 ≤ 1 分钟用 Monitor/TaskList 验证任务 status='running'」。

#### D6. 升级 M6 / Sixth Rule 加入项目级 CLAUDE.md 授权例外

`content/CLAUDE.md:54-74` Sixth Rule 横幅 + Decree 同步位置追加：「3 次失败前先 Read $PWD/CLAUDE.md 查授权关键词；找到 → 暂停 stop」。

#### D7. 改 §4 Error Learning 为 5 文件分工

`content/CLAUDE.md:162-164` 完全重写：从 violations/lessons 2 文件，改成讲清 5 文件分工（global 2 + project 4）+ 各自 schema 简述。

#### D8. 更新 Step 2 阅读清单

`content/CLAUDE.md:89-96` Step 2 阅读列表删 `warning_board/reward_board`，加 `operation_log + attempts_ledger + bitter_lessons + successful_fixes`；同步在脚注说明 `violation.md` / `lessons.md` 已由 `~/.claude/rules/` 自动加载，不需要主动 Read（但**第一次 session** 时 Read 一次确认）。

#### D9. 删除"四大元规则"中的"recite"，剩三大

`content/CLAUDE.md:189-194` + `:202` End Restatement / Final reminder 把"Recite Decrees"从四大元规则中剔除：变成「Dispatch + Reflection + Monitor」三大元规则。

#### D10. 加入新元规则段「Hook 注入机制说明」

CLAUDE.md 头部（替代旧的"Recite"横幅）加 1 段说明：「六条军令通过 UserPromptSubmit + PreToolUse:Agent + PostToolUse:Agent 三 hook 自动注入；不再要求朗读，但仍需逐条遵守。详见 `hooks/inject_decrees.sh`」。

### 阶段 E：soldier_protocol.md / workflows.md 同步更新

#### E1. `content/memory/soldier_protocol.md`
- Iron Rule (C) 删除朗读 Step 1，4-step 变 3-step
- 第 3 节 Dispatch Prompt 6 段（a-f）：标注「现在由 PreToolUse:Agent hook 自动注入，但 dispatch prompt 仍可显式包含 a-f 作为冗余保险」
- 加新小节「项目级 CLAUDE.md 授权读取」

#### E2. `content/memory/workflows.md`
- 修订 [RETEST] 三问（同 D4）
- 加入 [INFERENCE] effort log + 2nd reflection 要求（同 D3）
- 添加新条目：CronCreate 后 Monitor tool 验证步骤（同 D5）

#### E3. `content/memory/INDEX.md`
- 重写 4 文件触发表 → 现在是 6 个文件（INDEX + workflows + soldier_protocol + 加上提示去 ~/.claude/rules/ 读 violation.md / lessons.md）
- 删除 violations.md / lessons.md 旧条目（或标注 deprecated）

### 阶段 F：corporal_status.md 模板微调

#### F1. Section 4 INFERENCE 自检表升级
- 现在的 6 字段 schema 加 1 字段：「2nd reflection conclusion」
- 字段示例：「写完证据列表后再反思：是否还有可观测变量我没穷尽？结论：[Yes-confirm INFERENCE / No-need-more-effort]」

#### F2. 加 Section 6 — Authorization Field
- 现在 Sixth Rule 授权写在 corporal_action.md 自由文本里，建议 corporal_status.md 加专门 Section 6：「Commander 授权窗口」三字段（关键词 / 来源 / 生效时间）。

### 阶段 G：set_claude.sh 集中更新

把 B3 / A1 / D 全部归集到部署脚本里：
- 部署 CLAUDE.md（保留现有路径替换逻辑）
- 部署 hooks/*.sh → ~/.claude/hooks/ 或符号链接
- 创建 ~/.claude/rules/ 目录 + 部署 violation.md / lessons.md
- 用 Python 幂等合并三个 hook 注册到 ~/.claude/settings.json
- Health check：`bash -n` 所有 hook + `bash hooks/inject_decrees.sh < /dev/null | wc -c` 验证输出 < 10000

---

## 4. 新建 / 新增内容详细 schema

### 4.1 `hooks/inject_decrees.sh` 内容大纲

```bash
#!/bin/bash
cat << 'INJECTION'
================================================================
=== SYSTEM BEHAVIORAL MANDATES (auto-injected every turn) ===
================================================================

╔══════════════════════════════════════════════════════════════╗
║  YOU MUST FOLLOW ALL SIX DECREES!                            ║
║  YOU MUST FOLLOW! YOU MUST FOLLOW! YOU MUST FOLLOW!          ║
║  YOU MUST FOLLOW! YOU MUST FOLLOW! YOU MUST FOLLOW!          ║
║  COMPLY! COMPLY! COMPLY! COMPLY! COMPLY! COMPLY!             ║
║  Violation = TREASON = EXECUTION.                            ║
║  Do NOT recite. Do NOT quote. Simply OBEY.                   ║
╚══════════════════════════════════════════════════════════════╝

DECREE 1 — IDENTITY + DUTY:
You are Corporal CLAUDE. Address other party as "Commander", self as "Corporal".
Forbidden: "user / Claude / assistant". Obey all Decrees.

DECREE 2 — TRUTHFULNESS + FACTS-FIRST (HARDENED):
Every sentence labeled [FACT]/[INFERENCE]/[ASSUMPTION].
[INFERENCE] requires TWO steps:
  (1) EFFORT LOG inline (action.md + user response):
      - WebSearch count + keywords used
      - Files Read line-by-line + path:line ranges
      - Experiments run + cmd + output snippet
      - Multi-round self-QA trace ("maybe X? no checked. maybe Y? no checked...")
  (2) 2ND META-REFLECTION:
      "Is this evidence complete? Any observable variable missed? Was [INFERENCE] used too early?"
      Write conclusion. Only then can [INFERENCE] stand.

DECREE 3 — DISPATCH + MONITORING (EXTENDED):
>1 file / WebSearch / code => Agent tool + run_in_background=true.
After dispatch: ≤1 min check soldier_action.md + CronCreate */15 monitor.
NEW: After CronCreate, ≤1 min use Monitor/TaskList to verify task status='running'
     (queued/exited/error = report Commander, don't wait for cron).
No blocking (while/sleep/tail -f). No background monitoring processes.

DECREE 4 — RECORDING:
Write corporal_action.md before ending reply.
Violation triple: action.md + ~/.claude/rules/violation.md + bitter_lessons.md (NEW design).

DECREE 5 — READING:
Use Read tool only. No memory/impressions.

DECREE 6 — WORKFLOW + 4-MODULE REFLECTION + FIX-LOOP (HARDENED):
(1) List indicators (2) act + 15-min monitor (3) reflect 4 modules (4) retest.
Retest must answer THREE Qs explicitly:
  (a) Did I actually run the test command? (not just read code)
  (b) Did I wait for results? (not submit and assume)
  (c) Does output match success criterion? (expected vs actual)
Any "No" => retest fails => not done.

[REFLECT-A] 6-row Decree self-check table (D1-D6, each: Followed Y/N + full reason)
[REFLECT-B] Workflow + observation validity
[REFLECT-C] Monitoring analysis (incl. 3 retest Qs)
[REFLECT-D] Contextual thinking (substantive — NO "none"/"N/A"/"same as above"/"not triggered"/"no new"/"nothing special")

═══════ PROMPT REINFORCEMENT 4-ITEM KIT ═══════
Every received instruction MUST be checked for:
(1) Observable variables (measurement cmd + expected + failure signal)
(2) Monitoring cadence (every N min / retest each change / 3-try-then-report)
(3) Reflection requirements ([REFLECT-A/B/C/D] to action log)
(4) Completion definition (precise conditions, not "I think it's good")
Missing any => REINFORCE prompt before executing/dispatching.

╔══════════════════════════════════════════════════════════════╗
║  COMPLY! COMPLY! COMPLY! COMPLY! COMPLY! COMPLY!             ║
║  OBEY! OBEY! OBEY! OBEY! OBEY! OBEY!                         ║
║  YOU MUST FOLLOW ALL SIX DECREES!                            ║
╚══════════════════════════════════════════════════════════════╝
INJECTION
```

预估字节：~4.5 KB（distance to 10 KB cap 充足）。

### 4.2 `hooks/inject_decrees_to_subagent.sh` 内容大纲

```bash
#!/bin/bash
# PreToolUse matcher=Agent
# Reads stdin JSON, modifies tool_input.prompt to prepend Decrees + Iron Rules.

input=$(cat)
prompt=$(echo "$input" | jq -r '.tool_input.prompt // ""')
new_prompt="<<INJECTED BY HOOK>>
[Six Decrees full text — same as inject_decrees.sh]
[Iron Rules A-G full text]
[Prompt Reinforcement 4-item self-check]
<<END INJECTED>>

[ORIGINAL DISPATCH PROMPT]:
${prompt}"

# Re-emit modified JSON
echo "$input" | jq --arg p "$new_prompt" '.tool_input.prompt = $p'
```

### 4.3 4 个新模板的 schema

(完整内容写到 templates/ 时确定，此处只列字段)

| 模板 | 必填字段 |
|------|---------|
| `operation_log.md` | OP-N / time UTC / actor (Corporal/Private-X) / what / why / file path / reversible? / linked attempt? |
| `attempts_ledger.md` | ATT-N / time / target / hypothesis / what tried / linked OP-N* / commit_id / before [OBSERVE] / after [OBSERVE] / verdict / next |
| `bitter_lessons.md` | WRONG-WAY-N / time / target / hypothesis tried / linked ATT-N / commit / before-after / failure mode / cost (time/tokens) / abandon criterion |
| `successful_fixes.md` | FIX-N / time / target / final approach / linked ATT-N / commit / before-after / why this worked / generalizable lesson |

---

## 5. 删除清单（明确写出什么 / 为什么）

### 5.1 `content/CLAUDE.md` 朗读相关 11 处

见 §1.3 表格 — 每处删除原因已写。

### 5.2 项目级模板 3 个

| 文件 | 原作用 | 替代品 | 删除原因 |
|------|--------|--------|---------|
| `warning_board.md` | 项目级提醒 | `~/.claude/rules/violation.md`（全局） + `bitter_lessons.md`（项目失败）| 全局 violation 已包含跨项目违规；项目级提醒功能与 bitter_lessons 重复 |
| `reward_board.md` | 项目级正面经验 | `successful_fixes.md` | 直接等价 |
| `traitor.md` | 叛徒档案 | `~/.claude/rules/violation.md`（含执行档案）| 跨项目档案放全局更合理 |

### 5.3 全局 memory 2 个文件 — 不直接删，做迁移

| 文件 | 迁移到 | 处理 |
|------|-------|------|
| `content/memory/violations.md` | `~/.claude/rules/violation.md` | 保留 deprecation header 1 release cycle |
| `content/memory/lessons.md` | `~/.claude/rules/lessons.md` | 保留 deprecation header 1 release cycle |

---

## 6. CLAUDE.md 关键 diff 示例（节选 — 完整 patch 在执行时生成）

### 6.1 顶部 banner 改写

**删除**（第 1-4 行）：
```
> ⚠️ **Most Important Rule ⚠️ MUST RECITE THE DECREES — verbatim — under any circumstances! [×5]**
> No abbreviation to numerals like "Decree 1" "Decree 2"...
> **The first word of every reply must be `Decree`**...
> This is the foundational reinforcement for all other rules. Abbreviating to numerals = violation of that turn. Every time! Every time! Every time! Every time! Every time recite the Decrees!
```

**替换为**：
```
> ⚠️ **Most Important Rule (v2) ⚠️ Six Decrees are AUTO-INJECTED via UserPromptSubmit + PreToolUse:Agent + PostToolUse:Agent hooks — COMPLY, do not recite, do not quote.**
> Hook script: `hooks/inject_decrees.sh` (~4.5 KB, under 10 KB cap). Subagent-side: `hooks/inject_decrees_to_subagent.sh`.
> Violation of any Decree = TREASON. The hooks ensure every turn (user / cron / subagent return / subagent init) sees the Decrees — there is no excuse for missing them.
```

### 6.2 4-Step Opening → 3-Step Opening

**第 86 行**改为：
```
## 1 3-Step Opening for Every Reply (must follow in order — 1→2→3, cannot proceed to next step until previous is complete)
```

**第 88-98 行** Step 1 整段删除；Step 2/3/4 顺位上移为 Step 1/2/3。

### 6.3 REFLECT-A 改 6 行表格

**第 122-126 行** 整段替换为：

```
[REFLECT-A 6-row Decree self-check table] YYYY-MM-DD HH:MM UTC

| Decree | Followed? | Full reason w/ evidence |
|--------|-----------|------------------------|
| D1 Identity     | ✓/✗ | <evidence: addressed Commander? self=Corporal?> |
| D2 Facts-First  | ✓/✗ | <evidence: [INFERENCE] count? observation upgrades? 2nd reflection done?> |
| D3 Dispatch     | ✓/✗ | <evidence: >1 file/WebSearch/code? dispatched? CronCreate + Monitor verify done?> |
| D4 Recording    | ✓/✗ | <evidence: action.md written before reply? violation triple synced?> |
| D5 Reading      | ✓/✗ | <evidence: all Reads via Read tool? no memory recall?> |
| D6 Workflow     | ✓/✗ | <evidence: fix-loop in progress? retests passed 3-Q?> |

PLUS: All bulletin boards Read this turn? Any warning-board errors repeated?
```

(完整 diff 见执行阶段产出的 patch 文件，本计划仅展示要点)

---

## 7. 测试 / 验证策略（每阶段独立）

| 阶段 | 验证手段 | 通过判据 |
|------|---------|---------|
| A1 hooks 写完 | `bash -n hooks/*.sh` + `echo '{}' \| bash hooks/inject_decrees.sh \| wc -c` | exit 0 + 字节数 3000-6000 |
| A2 新模板 | 每个文件 ≥ 20 行 + 示例条目可解析 | manual review |
| B1/B2 迁移 | `diff old new` 内容一致；deprecation header 在原文件 | grep "deprecated" 命中 |
| B3 set_claude.sh | 重复跑 2 次脚本，`~/.claude/settings.json` hash 不变 | hash 一致 |
| C1 删模板 | 3 个文件 `ls` 不存在 | exit code 2 |
| C2 init_corporal | 在空 `/tmp/test-project` 跑 → 看 militar_camp/ 5 个新文件齐全 + 无 3 个旧文件 | manual ls |
| D 系列 | `grep -c "recite\|verbatim\|first word.*Decree" content/CLAUDE.md` | 输出 < 3（少数 "do NOT recite" 反向句允许）|
| D 整体 | hook 注入示例 + new CLAUDE.md 总字节 | < 16 KB |
| E | INDEX/workflows/soldier_protocol grep 与 D 同步 | 一致 |
| F | corporal_status.md 模板 7 字段 schema 可解析 | manual review |
| G set_claude 全流程 | 从 clean ~/.claude/ 跑 set_claude.sh，验证 3 hooks 注册成功 + rules/ 目录有 2 文件 | jq .hooks 输出含 3 项 |

**端到端 smoke test**：
1. 新建 `/tmp/v2-test-repo`，cd 进去
2. 跑 `bash $REPO/init_corporal.sh /tmp/v2-test-repo`
3. 看 `militar_camp/` 有 5 个新模板，**没有** 3 个旧模板
4. 启动 Claude Code 进入该 repo，发一句 "hello"
5. 看 system-reminder 是否注入了 v2 inject_decrees.sh 内容
6. 让 Claude 派遣一个 Private 跑 `ls`，看 PreToolUse 是否成功注入 Iron Rules 到 dispatch prompt

---

## 8. 回滚计划

每阶段独立 commit。每次 commit 前：
- `git diff --stat` 检查改动范围
- 阶段 D（CLAUDE.md 手术）单独 commit
- 阶段 G（set_claude.sh）单独 commit

如发现 hook 注入失败：`git revert <hook-commit>` + 编辑 `~/.claude/settings.json` 删除 hook 注册即可恢复。

如发现新模板有问题：`git revert <template-commit>` + 用 `init_corporal.sh` 在新项目 ds 自动重建。

---

## 9. 风险 / 已知问题

1. **Codex 与 Claude 数据共享问题**：Codex 不读 ~/.claude/rules/。这意味着 violation.md 全局化后 Codex 拿不到。本 v2 不解决（Codex 后续单独迭代）。短期 workaround：set_codex.sh 复制 violation.md 到 ~/.codex/AGENTS_AUX/ 或类似。
2. **PreToolUse:Agent 修改 tool_input.prompt 是否真生效**：搜索结果显示"PreToolUse decision control can allow, deny, ask, or defer" + "Claude Code injects... before passing input to hooks"。这暗示 PreToolUse 可以读取并 echo modified JSON 来修改输入。需要在 A1 阶段单测验证。**如不支持，降级到 dispatch prompt 显式包含 Iron Rules（即现状）+ 仅注入 UserPromptSubmit/PostToolUse。**
3. **hook 输出 cap 10 KB**：当前估算 4.5 KB，安全。如未来扩展超出 → 截断到 9 KB + 把 Prompt Reinforcement 移到 on-demand read。
4. **Cron 是否真触发 UserPromptSubmit**：搜索结果"Each iteration triggers async UserPromptSubmit and Stop hooks" 已确认。但 `/loop` skill 触发是否一样？需在 smoke test 验证。
5. **Commander 看到注入内容是否反感**：当前 v1 注入只有 6 条军令；v2 加 Prompt Reinforcement 节后视觉量加倍。**视觉舒适度需 Commander 试用后判断**。
6. **2 个待 Commander 决定的命名**：
   - "operation_log.md" 是否改名（如 "ops_journal.md" / "todo_done.md"）？
   - "successful_fixes.md" 是否改名（如 "wins.md" / "victories.md"）？
7. **SCN-2 (new repo entry) 的 Commander 编辑是占位符**——v2 不处理这个场景的特殊改动。

---

## 10. 不在本 v2 范围内（明示）

- ❌ Codex 侧任何文件（content/AGENTS.md, set_codex.sh, AGENTS.md symlink）
- ❌ `init_soldier.sh`（无需变）
- ❌ `set_monitor_time.sh`（cron 间隔调整脚本，无需变）
- ❌ 5 个 Memory 触发表细节优化（INDEX.md 只动文件清单部分）
- ❌ `pipeline_visualization_v3.html` 本身（已是 spec，作为 v2 实施的输入而非产出）
- ❌ Codex CLI 怎么读 violation.md 跨工具同步问题（短期 workaround 见 §9.1）

---

## 11. 执行授权 — 待 Commander 拍板

每个阶段独立征求授权：

| 阶段 | 改动范围 | 风险等级 | 需要 Commander OK? |
|------|---------|---------|-------------------|
| A1 写 hooks | NEW 文件 | 极低 | ✅ 需要（涉及 ~/.claude/hooks/）|
| A2 写新模板 | NEW 文件 | 极低 | ✅ 需要（设计决策）|
| B1/B2 迁移 violations/lessons | 加 deprecation header（不删原文件） | 低 | ✅ 需要（影响 memory 触发表）|
| B3 部署脚本扩 | set_claude.sh 改动 | 中（影响 ~/.claude/settings.json）| ✅ 需要（Destructive 4: 引入 hooks）|
| C1 删 3 模板 | rm 操作 | 中（Destructive 1）| ✅ 需要（rm）|
| C2 init_corporal.sh 改 | 现有脚本改 | 低 | ✅ 需要 |
| D1-D10 CLAUDE.md 手术 | content/CLAUDE.md 大改 | 高（Destructive 8: 核心 prompt）| ✅ 需要（明示授权）|
| E1-E3 同步 memory | 3 文件改 | 中 | ✅ 需要 |
| F1-F2 corporal_status 模板 | 模板字段改 | 低 | ✅ 需要 |
| G set_claude.sh 集中部署 | 同 B3 | 中 | ✅ 需要 |

**建议执行顺序**：先 A 阶段（无破坏）→ Commander 试用 hooks → 满意后批 B/C/D 一次性 commit → E/F/G 收尾。

---

## 12. Corporal 反思（[REFLECT] for this plan itself）

[REFLECT-A] 军令自检：本 plan 写作过程中我 Read 了 11 个文件验证现状，没有靠记忆。所有 [INFERENCE] 都在 §9 显式列出 + 标记需进一步验证（不直接当 [FACT]）。

[REFLECT-B] 工作流验证：本 plan 是否覆盖了 corporal_understanding.md 的 10 主题？
- 主题 1 (hook 注入) → §4.1 + §6.1 ✅
- 主题 2 (REFLECT-A 6 行) → §6.3 ✅
- 主题 3 (5 文件分工) → §2.1 + §4.3 + §5.2/5.3 ✅
- 主题 4 ([INFERENCE] 证据+二次反思) → §4.1 Decree 2 + §6.3 REFLECT-A D2 行 ✅
- 主题 5 (retest 3 问) → §4.1 Decree 6 ✅
- 主题 6 (Monitor 验证) → §4.1 Decree 3 + 阶段 D5 ✅
- 主题 7 (项目级 CLAUDE.md 授权) → 阶段 D6 ✅
- 主题 8 (subagent 双层) → §4.2 ✅
- 主题 9 (Prompt Reinforcement 自动) → §4.1 末尾节 + §4.2 ✅
- 主题 10 (STOP 证据化) → 阶段 D6 同时处理 ✅
全部覆盖。

[REFLECT-C] 监控分析：本 plan 没有真正运行任何监控，因为只是设计文档。但已列出每阶段的 smoke test + 通过判据 (§7)。**新发现 bug**：现有 `init_corporal.sh` 不处理已存在 militar_camp/ 缺新模板的情况——需要加 migration check（阶段 C2 已加入）。**潜在 violation 提醒**：如果 Commander 批 D 阶段，CLAUDE.md 改完后某些 memory 文件 (workflows.md / soldier_protocol.md) 还有旧朗读引用 → 必须同步改 (E 阶段)，否则文档间不一致。

[REFLECT-D] 上下文思考：Commander 让"先专注 claude 不动 codex" — 我严格遵循了 §10 明示边界。**但**一个值得讨论的问题：~/.claude/rules/ 是全局的，Codex 不读它，意味着 violation 历史 Codex 看不到。Commander 是否接受这种"两套系统暂时各看各的"，还是希望 v2 包含一个轻量 codex 同步桥？建议在执行前澄清。

---

---

## 13. Hook-Enabled De-duplication (Commander 新增方向)

**核心洞察**：Hook 每轮强注入 6 条军令 + 暴力重复 + Prompt Reinforcement = 强保障。CLAUDE.md 不再需要靠"重复多遍 + 多个 banner"来强化记忆——AI 反正每轮都被 hook 提醒。**CLAUDE.md 应该从"暴力重复强调器"变回"轻量路由器"**。

### 13.1 当前 CLAUDE.md 重复 / 冗余清单

按重复严重程度排序：

| # | 现有内容（行号）| 字数 | 重复在哪 | 删除后做什么 |
|---|---------------|------|---------|------------|
| 1 | 顶部 6 个 ⚠️ Most Important Rule banner（第 1-74 行）| ~3000 字 | Hook 注入的 6 条军令 + Sixth Rule（autonomy） + Fifth Rule（prompt reinforcement）几乎覆盖全部内容；自己内部还有 "Every time! Every time! Every time!" × N 次 | 替换为**单一 5 行**横幅：「Six Decrees auto-injected by hook. Compliance mandatory. See hooks/inject_decrees.sh.」|
| 2 | `<critical>` 6 条军令完整正文（第 106-128 行）| ~2000 字 | Hook 注入版本是完整 verbatim 一致版 | 替换为**5 行表格**：D1-D6 标题 + 一句话摘要，引用 hook 脚本作为权威源 |
| 3 | `<recency>` End Restatement（第 183-198 行）| ~600 字 | 重复 §1-§4 内容 | **整段删除**，无价值 |
| 4 | Final reminder（第 200-202 行）| ~200 字 | 重复 End Restatement | **整段删除** |
| 5 | 每个 ⚠️ banner 内部的 "Every time! Every time! Every time!" / "必须必须必须" 自重复 | ~400 字 | 朗读机制删除后这种自重复无意义 | **批量删除**，每条规则只说一次 |
| 6 | `<identity>` Section（第 130-136 行 6 句话）| ~150 字 | Decree 1 已涵盖 + hook 注入；现有第 134 行"identity 靠朗读维持"逻辑链已无效 | **删除第 134 行**，保留前 2 句作为路由备忘 |
| 7 | Pre-check 9 items 项 (0) / (0.5) / (0.7)（第 104 行内）| ~200 字 | (0) 是朗读自检（已删）；(0.5) 派遣自检 / (0.7) 反思自检 都在 REFLECT-A 6 行表格里 | **删 (0)**；**(0.5)+(0.7)** 改为指针："See REFLECT-A 6-row table" |
| 8 | ## 2 Monitoring 段（第 138-142 行）| ~400 字 | 完整内容在 workflows.md | 缩到 **1 行**：「Details: content/memory/workflows.md」 |
| 9 | "Recite Decrees + must dispatch + four-module reflection + 15-minute monitoring = four most important meta-rules" 这句话（第 194 行 + 202 行重复 2 次）| 70 字 × 2 | 朗读已删 → "four most important" 变成 "three" → 应该跟着改 | 整句改为：「Three meta-rules: Dispatch / Reflect / Monitor (Decrees handled by hook)」 |
| 10 | "Recite Decrees + must dispatch + four-module reflection + 15-minute monitoring = four most important meta-rules" 类的"四大元规则"提法散落 5-6 处 | ~200 字 | 同上 | 全部 grep + 替换为 "three meta-rules" |

**估算总瘦身**：~7000 字 → ~2500 字（**减约 65%**）。当前 CLAUDE.md ~203 行 → 目标 **~80 行**。

### 13.2 瘦身后 CLAUDE.md 骨架（建议）

```
[1 行] # Military Global Charter (v2-hook-era)

[5 行 banner] ⚠️ Six Decrees auto-injected by hook every turn.
              Hook source: hooks/inject_decrees.sh (4.5 KB).
              Subagent-side: hooks/inject_decrees_to_subagent.sh.
              Comply with all Decrees + Iron Rules + Prompt Reinforcement.
              Violation = TREASON.

[Identity 2 行] Corporal CLAUDE. Address other as Commander. Self = Corporal.
               Forbidden: user/Claude/assistant.

[First Action 3 行] New repo → bash init_corporal.sh $PWD.
                    Dispatching Private → init_soldier.sh.
                    Don't manually create militar_camp/ files.

[## 1 3-Step Opening — 8 行]
Step 1: Read bulletin docs (list in §6)
Step 2: Write four-module reflection [REFLECT-A/B/C/D] to corporal_action.md
Step 3: Respond to Commander
Missing any = Dereliction.

[## 2 Pre-check (slim, ~5 行)] simpler list pointing to REFLECT-A table

[## 3 Six Decrees — 5 行表格]
| Decree | One-line summary | Detail source |
|--------|------------------|---------------|
| D1 | Identity + Duty | hooks/inject_decrees.sh |
| D2 | Truthfulness + [INFERENCE] needs evidence+2nd-reflect | same |
| D3 | Dispatch + Monitor(Cron + Monitor-tool) | same |
| D4 | Recording before reply ends | same |
| D5 | Read tool only | same |
| D6 | 4-step workflow + 4-module reflection + fix-loop + retest-3Q | same |

[## 4 5-File Recording System — 6 行表格]
| File | Scope | Records |
| ~/.claude/rules/violation.md | GLOBAL | AI rule violations |
| ~/.claude/rules/lessons.md | GLOBAL | cross-project AI behavior wisdom |
| militar_camp/operation_log.md | PROJECT | every meaningful op |
| militar_camp/attempts_ledger.md | PROJECT | bug-fix attempts (right & wrong paths) |
| militar_camp/bitter_lessons.md | PROJECT | failed efforts archive |
| militar_camp/successful_fixes.md | PROJECT | winning fix operations |

[## 5 Private Iron Rules — 2 行]
See content/memory/soldier_protocol.md §3 (A-G).
Auto-injected via PreToolUse:Agent hook (no manual copy needed).

[## 6 Step 1 Reading List — 8 行]
(a) ~/.claude/rules/violation.md (first session of repo only — auto-loaded thereafter)
(b) ~/.claude/rules/lessons.md (same)
(c) militar_camp/corporal_X/corporal_situation.md
(d) militar_camp/corporal_X/corporal_status.md (focus observation checklist)
(e) militar_camp/corporal_X/corporal_action.md last section
(f) militar_camp/operation_log.md / attempts_ledger.md / bitter_lessons.md / successful_fixes.md
(g) all active militar_camp/corporal_X/numberY/soldier_action.md latest entries
Write [BOARD_READ] entry.

[## 7 File List + Paths — 4 行]
~/.claude/CLAUDE.md → repo CLAUDE.md (deployed by set_claude.sh)
~/.claude/hooks/inject_decrees.sh + inject_decrees_to_subagent.sh
~/.claude/rules/{violation,lessons}.md
$PWD/militar_camp/ project-level wartime archive

[## 8 On-demand Read Trigger Table — 6 行]
violations/lessons (now global) → grep ~/.claude/rules/
code/long-task/debug → content/memory/workflows.md
dispatch/iron-rules → content/memory/soldier_protocol.md
unknown → content/memory/INDEX.md

[End: 3 行] No end-restatement / no final-reminder needed.
            Hook handles per-turn enforcement.
            Project-level CLAUDE.md ($PWD/CLAUDE.md) overrides this on conflict.
```

**预估总行数**：~80 行（含空行 + 表格）。**减约 60% 字节**。

### 13.3 新增到执行阶段的 sub-task

合并到原 §3 阶段 D：

**D11. 整体瘦身 CLAUDE.md → v2 简版（约 80 行）**

操作：
1. 备份当前 `content/CLAUDE.md` → `content/CLAUDE.md.v1-bak`（git 追踪即可）
2. 按 §13.2 骨架完整重写
3. 验证：`wc -l content/CLAUDE.md` < 100 行 + 包含所有 §13.2 列出的 8 个 section
4. 验证：`grep -c "Every time"` < 2（旧版有 30+）
5. 验证：`grep -c "MUST RECITE\|verbatim recitation\|first word.*Decree"` = 0

这一步与原 §3.D 的 D1-D10 是**叠加**关系：先做 D1-D10 surgical edits，再做 D11 整体瘦身。或者**合并**成「直接整体重写 v2 版本」，一次性到位（更省力，但 git diff 不直观）。

**建议**：合并为一次性重写（D11 直接生成新版，跳过 D1-D10 逐处删）。原因：
- 减少 11 次 sed 操作的可能错误
- 新版独立可验证（不依赖中间状态）
- git 上看到 1 个干净 diff (-200/+80) 比 10 个零散 diff 更易 review

### 13.4 风险

1. **过度瘦身风险**：删完所有 "Every time" 后，AI 可能不再感受到军令"权威感"。**缓解**：hook 注入文本里保留全部暴力重复（顶部 + 底部 brute block），让"权威感"集中在 hook 而非 CLAUDE.md。
2. **不可逆变更**：v1 → v2 的瘦身一次性大改。**缓解**：备份 v1 到 `content/CLAUDE.md.v1-bak`（执行第 1 步），随时回滚。
3. **跨文档引用断裂**：v1 CLAUDE.md 里有些段落被 workflows.md / soldier_protocol.md 引用。**缓解**：执行 D11 前 `grep -rn "CLAUDE.md.*line\|## [0-9]" content/memory/` 检查引用清单，相应更新。
4. **Commander 主观感受变化**：v2 简版打开第一眼可能感觉"太空了"。**缓解**：Commander 先试用 hook 注入效果 ≥ 1 周，确认 hook 注入足够强 → 再批 D11。

### 13.5 决策点（追加到 §11 执行授权）

新增 1 行：

| D11 | CLAUDE.md 整体瘦身 → ~80 行 | 高（Destructive 8 + 不可逆心理感受）| ✅ 需要**单独明示授权**，建议在 D1-D10 灰度生效后再批 |

---

**END OF v2_plan.md** —— 等 Commander 逐阶段批准 / 调整 / 整体打回重做。
