# DEVELOPER.md — barry-workflow 开发者指南

写给：要修改本仓库代码或把它移植到别的 CLI（如 Codex）的人。
读完顺序：先 [`system_overview.md`](system_overview.md)（系统层抽象）→ 本文（实现层 + 依赖矩阵）→ 各模块 README / 注释。

---

## 1. 当前还活着的文档清单

仓库里有些 docs 是历史规划稿（已落地或已废弃），有些是常驻参考。**改代码前看这张表**。

| 文档 | 用途 | 状态 |
|---|---|---|
| [`README.md`](../README.md) / [`README.en.md`](../README.en.md) | 用户向：装/用/卸 | **常驻** |
| [`docs/system_overview.md`](system_overview.md) | 分层介绍：5 state / 控制机制 / 文件结构（一句话讲每个模块在干啥）| **常驻** |
| [`docs/DEVELOPER.md`](DEVELOPER.md) | 本文：开发者向，实现 + 依赖 | **常驻** |
| [`docs/skills.md`](skills.md) / [`docs/skills.zh.md`](skills.zh.md) | 30+ skill 清单 + 触发条件 | **常驻** |
| [`docs/shared_files_plan.md`](shared_files_plan.md) | shared workspace ledgers 改造的设计 + 牵连面 27 文件 | **历史决策记录**（已落地，留档解释 why） |
| [`docs/v2.1_plan.md`](v2.1_plan.md) / [`v2.2_plan.md`](v2.2_plan.md) | 历史迭代计划 | **历史**（已 land 大部分）|
| [`docs/v2.3_plan.md`](v2.3_plan.md) | 下一波要做的 12 项（含 P40 路径硬编码下沉）| **活动**——下一步改动的源头 |
| `docs/big_picture.{md,html}` / `docs/problem_discussion.{md,html}` / `docs/scenarios.html` / `docs/fsm_visualization.html` / `docs/pipeline_visualization_v4.html` / `docs/implementation.html` / `docs/pros_cons.md` | 早期演讲/可视化稿 | **historical**——不准/不再维护，仅留档 |
| `docs/p8_e2e_notes.md` / `docs/RESEARCH_NOTES_GOAL_HOOK.md` / `docs/plan_merge_main.md` | 内部备忘 | **internal-only**——不发 main，不必更新 |
| [`archive/README.md`](../archive/README.md) | 冬眠代码索引（含 `stop_self_audit.sh`） | **常驻** |

**改代码原则**：改了系统行为 → 同步 `system_overview.md` + 本文。改了内部规划 → 写到 `v2.3_plan.md`（或下一版 plan）。**不更新 historical/internal-only 文档**。

---

## 2. 各子系统：实现 + 依赖

按 [`system_overview.md`](system_overview.md) 的模块顺序展开。每条带（a）实现文件、（b）依赖 Claude Code 的什么功能、（c）改这里要小心什么。

### 2.1 FSM 状态注入

**做什么**：每轮 UserPromptSubmit 前往用户输入塞当前 state 的指令。

- **实现**：[`hooks/inject_router.sh`](../hooks/inject_router.sh) → 读 `state.md` 的 `current_status` → cat [`content/rules/router_<STATE>.md`](../content/rules/) 到 stdout
- **依赖 Claude Code**：
  - `UserPromptSubmit` hook（在 settings.json `hooks.UserPromptSubmit` 注册）
  - hook stdout 内容**自动拼接到用户 prompt 前面**（Claude Code 内置行为，非配置）
  - hook 收到 stdin JSON（`session_id`, `cwd`, `transcript_path`）—— Claude Code 协议
- **改这里小心**：stdout 体积——每轮都拼，太大会吃光上下文。当前 router_*.md 每个 < 25 行。

### 2.2 状态转换

**做什么**：模型主动调脚本切换 state，5 个事件 → 5 个目标状态。

- **实现**：[`hooks/transition.sh`](../hooks/transition.sh) — case 分支 + 重写 `state.md` YAML + 追加 `transitions.log` + cat 新 state 的 `states/<state>.md` 完整 spec 到 stdout
- **依赖 Claude Code**：
  - `Bash` 工具（模型主动 `bash transition.sh EVENT --reason=...`）
  - 脚本 stdout 在工具结果里返给模型——下一轮模型看到「Full pipeline for <NEW>」自动获取详细指引
- **改这里小心**：YAML 解析是 naïve regex（避免 PyYAML 依赖）；YAML 结构变了要同步 Python 内联段。

### 2.3 REFLECT 子 agent rebuttal

**做什么**：派一个新 agent 当审稿人，挑当前方案的刺，N 轮直到 `[CONSENSUS_REACHED]`。

- **实现**：
  - 协议在 [`content/rules/states/reflect.md`](../content/rules/states/reflect.md)
  - 模型按协议自己派 agent，写 `.barry_workflow/<sid>/reflection_<round>.md`
  - 没有专用 hook —— 完全靠 router 指令 + 模型自觉
- **依赖 Claude Code**：
  - **`Agent` 工具**（with `run_in_background=true` 强制）
  - 子 agent **不继承主上下文**（Claude Code 子 agent 是 fresh session，system prompt 由 hook 重生成）
  - 子 agent 的 jsonl 单独存在 `~/.claude/projects/<encoded>/<sid>/subagents/agent-<aid>.jsonl`
- **改这里小心**：Codex CLI 没有原生 `Agent` 工具——需用 `codex exec` + 文件传输模拟。详见 [`content/rules/codex_adapter.md`](../content/rules/codex_adapter.md)。

### 2.4 EXECUTE_LOOP 纪律

**做什么**：每个工具调用前后写 `[PLAN]` / `[OBSERVE]`；累计 3 次异常关键词 → 自决回 REFLECT。

- **实现**：
  - 纪律文字注入 router_EXECUTE_LOOP.md（一行强约束）
  - 自查 helper [`hooks/execute_loop_audit.sh`](../hooks/execute_loop_audit.sh) — grep action.md 行数 + 异常关键词
  - 阈值从 [`content/rules/workflow_config.yaml`](../content/rules/workflow_config.yaml) 的 `execute_loop.failure_budget` 读
- **依赖 Claude Code**：
  - 模型写 `Bash(append >> action.md)` 自己记录（没有内建 logging）
  - 没有 hook 阻止漏写——靠 router 重复提醒（每轮注入）

### 2.5 软提醒 hook（pretooluse）

**做什么**：工具调用前最多塞一条 ≤100 字符提醒。永不 block。

- **实现**：[`hooks/pretooluse_short_nudge.sh`](../hooks/pretooluse_short_nudge.sh) — 按 tool name 分支 + 计数器 `.barry_workflow/<sid>/nudge_counters.json`
- **依赖 Claude Code**：
  - `PreToolUse` hook
  - hook 返回 JSON 结构 `{hookSpecificOutput: {hookEventName, permissionDecision, permissionDecisionReason}}` 用 `allow` —— Claude Code 协议字段
  - `permissionDecision: "deny"` 是否真能 block 当前**未验证**（v2.3 P33）
- **改这里小心**：返回 JSON 必须符合 Claude Code 解析，否则 hook fail。

### 2.6 状态合规检查 hook（state_enforce）

**做什么**：工具调用后按当前 state 检查是否用了禁工具，stderr 喷一行警告。

- **实现**：[`hooks/state_enforce.sh`](../hooks/state_enforce.sh) — case 分支 BOOT/PREPARE/REFLECT，针对工具白名单 mismatch 输出警告
- **依赖 Claude Code**：
  - `PostToolUse` hook（matcher=*）
  - stderr 内容**会被 Claude Code 当作上下文反馈给模型**——下一轮模型会看到「BOOT state — Write 不允许」
- **改这里小心**：必须 `exit 0`，否则被 Claude Code 当 hook failure。

### 2.7 自我进化：scenario patches

**做什么**：用户给特定 task type 起草 patch，BOOT 阶段加载。

- **实现**：5 个示例 patch 在 [`content/rules/patches/`](../content/rules/patches/)
- **依赖 Claude Code**：纯文件读写，无 CLI 特性依赖
- **现状**：手动加载——AI 看 patch 文件名 + 自决是否 `cat`。auto-load 在 [v2.3 P32](v2.3_plan.md)。

### 2.8 项目 ledger 自动 seed

**做什么**：每次 UserPromptSubmit，若 `$PWD/workspace/` 存在但 4 个共享 ledger 缺，自动从模板补。

- **实现**：[`hooks/session_boot.sh`](../hooks/session_boot.sh) 末尾的「v2.3 seed」段；备用路径 [`scripts/new_task.sh`](../scripts/new_task.sh)
- **依赖 Claude Code**：
  - `UserPromptSubmit` hook（与 inject_router 同事件，两 hook 都注册）
  - 不依赖任何 CLI 工具，纯 bash mkdir / cp

### 2.9 Session viewer

**做什么**：本地 HTML 三栏检视器（agent 树 / state + reflection / 清洗 transcript）。

- **实现**：[`viewer/index.html`](../viewer/index.html) + [`viewer.js`](../viewer/viewer.js) + [`scripts/build_viewer_manifest.py`](../scripts/build_viewer_manifest.py) + [`scripts/extract_transcript.py`](../scripts/extract_transcript.py)
- **依赖 Claude Code**：
  - 会话 JSONL 路径约定 `~/.claude/projects/<encoded-cwd>/<sid>.jsonl`
  - 子 agent JSONL `~/.claude/projects/<encoded-cwd>/<sid>/subagents/agent-<aid>.jsonl`
  - encoded-cwd 编码：`/` 和 `_` 都→`-`
  - JSONL 每行 schema：`{message: {usage: {input_tokens, output_tokens, cache_read_input_tokens, ...}}, timestamp, ...}`
- **改这里小心**：JSONL schema 是反向工程结果，Claude Code 版本升级可能变。

### 2.10 cache_hit_map（PREPARE 自报 + 跨 session 继承）

**做什么**：让模型在 PREPARE 显式声明「这些 artifact 已经在我 KV cache 里，不用 Read」——把隐式的 cache 复用变成可审计的声明。viewer 里以 collapsible 块展示。

- **实现**：
  - [`hooks/prepare_helper.sh`](../hooks/prepare_helper.sh)：枚举 `workspace/*.md` + `workspace/<task>/goal.md` + `.barry_workflow/<sid>/{state,action}.md` + `CLAUDE.md` + `goal.md`，每条 emit `<path>: {sha1: <hash>, hit: UNKNOWN}` 行作为 stub
  - 模型在 PREPARE 把每行 `UNKNOWN` 改成 `YES`（已在 KV 缓存）或 `NO`（必须本轮 Read），粘回 `state.md` 的 `cache_hit_map:` 块
  - [`hooks/session_boot.sh`](../hooks/session_boot.sh) P17 段：新 session 启动时 regex 抽上一个 sid 的 `cache_hit_map:` 块整体复制进新 `state.md`（key inherit）——实现「跨 session 上下文复用」
  - [`viewer/viewer.js`](../viewer/viewer.js) `parseState()` 抓 raw block，渲染成左栏 `<details>cache_hit_map</details>`
- **记录什么**：
  - artifact 绝对路径（项目内相对路径）
  - sha1（防止 stale 自报——sha1 变了说明文件本身已变）
  - `YES` / `NO` / `UNKNOWN` 三态
  - 误判（声称 YES 实则 NO）= AI behavioral error → 后续发现写 `workspace/rule_violations.md`
- **依赖 Claude Code**：
  - 无内置 KV cache 接口——纯靠模型自省 + 文档约束。Claude Code 不暴露 cache hit 信号给 hook
  - `~/.claude/projects/<encoded>/<sid>.jsonl` 的 `cache_read_input_tokens` 字段（viewer 也用）是事后唯一可观测的 cache 信号，但不细到 per-artifact
  - 跨 session 继承靠 `.barry_workflow/<sid>/` 目录结构（hook 自定义），不依赖 Claude Code 任何 session 链路
- **改这里小心**：
  - prepare_helper 的 artifact 枚举范围改了 → session_boot.sh inherit regex 可能漏字段
  - cache_hit_map YAML 结构改了（比如改 nested map）→ viewer.js `parseState()` 的 `cache_hit_map_raw` regex 要跟着改
  - **没人验证 YES 是否真的 cache hit**——这是设计妥协，不是 bug；移植到 Codex 时若有原生 cache 信号可以替换为强校验

### 2.11 Skills

**做什么**：30+ 独立技能，按 SKILL.md 的 frontmatter `description` 自动召回。

- **实现**：[`skills/<name>/SKILL.md`](../skills/)
- **依赖 Claude Code**：
  - 全局目录 `~/.claude/skills/<name>/` —— Claude Code 启动时扫描
  - SKILL.md frontmatter 由 Claude Code 解析（YAML）
  - 触发：用户 `/<skill-name>` OR Claude 判断当前任务匹配 description 时自动加载
- **改这里小心**：description 写法影响召回准确度（写得太泛会乱触发）。

---

## 3. Claude Code 功能依赖矩阵

总览：这个仓库依赖 Claude Code 哪些功能。**移植到别的 CLI（Codex 等）必须逐项映射。**

| Claude Code 功能 | 用途 | 用在哪 | 移植难度 |
|---|---|---|---|
| `UserPromptSubmit` hook | 每轮注入 router 文本 + 自动建 session 文件 | inject_router / session_boot | **核心**——Codex 用 `~/.codex/agents.d/` 或环境变量等价物 |
| `PreToolUse` hook | 工具调用前软提醒 | pretooluse_short_nudge | 中——Codex 有自己的 pre-exec hook |
| `PostToolUse` hook | 工具调用后状态合规警告 | state_enforce | 中——同上 |
| hook stdout → 拼接到 prompt | router 注入机制 | inject_router | **关键**——Codex 行为可能不同 |
| hook stderr → 反馈模型 | 状态合规警告 | state_enforce | 待验证 |
| hook JSON 返回 `permissionDecision` | 软提醒不 block | pretooluse | Codex 可能不支持，需 fallback |
| `Agent` 工具 + `run_in_background=true` | REFLECT rebuttal + EXECUTE 取证 | 模型主动调 | **核心**——Codex 用 `codex exec` 子进程模拟 |
| 子 agent 独立 jsonl | viewer 拉子 agent transcript | build_viewer_manifest | Codex 需自定义 transcript 存储 |
| `Monitor` 工具 / 长 bg 任务 | EXECUTE_LOOP 长跑监控 | router_EXECUTE 提示 | Codex 没有，需 `tail -f` + `BashOutput` 模拟 |
| `Read` / `Edit` / `Write` / `Bash` 工具 | 全部 state 都用 | router 工具白名单 | Codex 有等价物 |
| 会话 JSONL `~/.claude/projects/<encoded>/<sid>.jsonl` | viewer + token 统计 | viewer | Codex 用 `~/.codex/sessions/` 不同 schema |
| `Skill` 自动召回 | SKILL.md frontmatter | skills/ | Codex 不支持自动召回——退化为手动 prompt |
| `settings.json hooks` 字段 | 注册 4 个 hook | set_claude.sh | Codex 用 `~/.codex/config.toml` |
| `~/.claude/CLAUDE.md` 自动加载 | 全局指令 | content/CLAUDE.md → 部署 | Codex 用 `AGENTS.md` |
| jsonl `cache_read_input_tokens` 字段 | cache_hit_map 事后审计的唯一观测 | viewer + PREPARE 自报 | Codex 需检查 session 是否暴露 cache 统计 |

**详细映射**：[`content/rules/codex_adapter.md`](../content/rules/codex_adapter.md)。

---

## 4. 怎么改东西（开发流程）

### 加一个新 state

1. 起名 `XYZ`
2. 写 [`content/rules/router_XYZ.md`](../content/rules/) — quick rules + always-on footer
3. 写 [`content/rules/states/xyz.md`](../content/rules/states/) — 完整 pipeline + 完成标准
4. 改 [`hooks/transition.sh`](../hooks/transition.sh) case 加 `<EVENT>) NEW=XYZ ;;`
5. 改 transition.sh 的 STATE_DOC case 加 `XYZ) STATE_DOC="xyz.md" ;;`
6. 改 [`viewer/viewer.js`](../viewer/viewer.js) `FSM_STATES` 数组加 `"XYZ"`
7. 文档同步：`system_overview.md` §2 / §3，README.md §3 状态机表

### 加一个 hook

1. 写 `hooks/foo.sh`，开头 source `_session_lib.sh`，结尾 `exit 0`
2. 在 [`set_claude.sh`](../set_claude.sh) line 241 的列表加 `foo.sh`
3. 改 set_claude.sh 的 `~/.claude/settings.json` 注册段加 hook 条目
4. 文档：`system_overview.md` §4.3 + 本文 §2

### 加一个 scenario patch

1. 写 [`content/rules/patches/yyy.md`](../content/rules/patches/) — frontmatter `applies_to:` + 内容
2. 改 router_EXECUTE_LOOP / BOOT 那行 patches 清单加 `yyy.md`
3. 暂时手动加载（v2.3 P32 后会自动）

### 加一个 skill

1. `mkdir skills/<name> && touch skills/<name>/SKILL.md`
2. SKILL.md frontmatter 写 `description:`（影响召回触发）
3. 用户跑 set_claude.sh 后 symlink 自动接到 `~/.claude/skills/`

### 改可调参数

1. 改 [`content/rules/workflow_config.yaml`](../content/rules/workflow_config.yaml)
2. 想用新参数的 hook 用 `_session_lib.sh` 的 `read_config` 读
3. 不要硬编码——改后跑 grep 确认没残留

---

## 5. 移植到 Codex 的开工清单

按依赖矩阵（§3）逐项确认 Codex 能不能做。重点：

1. **hook 机制**：Codex 的 hook 等价物是什么？stdout/stderr/exit code 协议？
2. **`Agent` 工具**：用 `codex exec` 子进程包一个伪 Agent 工具，主 codex `Send` 文本任务 → 子进程跑 → 主从文件读结果
3. **会话 jsonl 路径**：Codex 把转录存哪里？schema 是否兼容 viewer 的 token usage 解析
4. **全局指令**：Codex 用 `AGENTS.md`（而非 `CLAUDE.md`）——`set_claude.sh` 需要分支或新写 `set_codex.sh`
5. **router 注入机制**：Codex 是否在每轮自动 cat 某个文件到 prompt 前面？如不，需要其他注入路径（env var / wrapper script）

跑通最小工作流：BOOT → PREPARE → REFLECT（派 codex exec）→ EXECUTE_LOOP → END，全部在 codex CLI 内。

参考起点：[`content/rules/codex_adapter.md`](../content/rules/codex_adapter.md)（已有的工具映射表）。

---

## 6. 速查

- 我想知道某个 hook 做啥 → 看本文 §2 对应小节 + 直接 cat 那个 .sh
- 我想知道某个 state 在干啥 → [`system_overview.md`](system_overview.md) §2
- 我想知道整个流程 → [`system_overview.md`](system_overview.md) §3
- 我想知道下一步要做啥 → [`v2.3_plan.md`](v2.3_plan.md)
- 我想知道为啥某处这么设计 → 找对应 `vX.Y_plan.md` 或 `*_plan.md`
- 我要装/卸 → [`README.md`](../README.md)
