# v2 军纪系统设计方案 — 短指令路由器 + 长期可访问文件（修订版 v3 — 二审收敛）

> 一审 v3 修 codex 一审 [BLOCKER]=2 + [MAJOR]=3 + [MINOR]=1；本二审 v3 再修 codex 二审 [BLOCKER]=1（INDEX.md 双口径冲突）+ [MAJOR]=2（体检不可执行 / 闭环不实）+ [MINOR]=1（路径漂移）。所有 [事实] 来源见 `militar_camp/corporal_2/number5/soldier_action.md`、`number6/soldier_action.md`、`number7/soldier_action.md`。

## 术语对照表

短指令路由器 = short prompt router（主指令极简，细节路由外部文件）/ 启动注入预算 = startup-injection budget（每会话自动加载到上下文的字节上限）/ 磁盘语料预算 = on-disk corpus budget（按需读、不常驻上下文）/ 加载契约 = loading contract（工具官方加载入口与我们文件的对接方式）/ 单一规范目录 = single canonical directory（双工具读同一份）/ 体检 = preflight check（部署脚本运行前能力检测）/ 降级 = fallback（功能不可用时退回更稳路径）/ 钩子 = hook（工具事件触发的脚本；本 v2 **不加** memory 相关 hook，仅保留现有 PostToolUse=Bash 调试 logger）。

## 1 自检前置机制（写在每个 repo 根目录的 CLAUDE.md/AGENTS.md 顶部）

每次回复开头列出 7 条「上手前必答清单」，任一答否 = 立刻在流水文件写「待补」+ 修复后再上手。

1. 三公告板（`warning_board.md` / `reward_board.md` / `corporal_situation.md`）已用 Read 工具阅读？
2. 本任务的可观察指标已列入 `corporal_status.md`「## 观察项清单」段（每条 5 字段）？
3. 每句话的标注（[事实] / [推论] / [假设]）都有来源 / 推理链 / 假设前提？
4. 本次操作前流水（`corporal_action.md` 或 `soldier_action.md`）已先记录后操作？
5. memory（`content/memory/lessons.md` + `violations.md`）已 grep 查同类历史？
6. 上次 session 历史违规（`content/memory/violations.md` 中的 W-XXX，按 `tags:` 字段 grep）我都看过，避免重蹈？
7. 任务模式（无状态 / 调研 / 动手）已写到 `corporal_status.md`，避免标错被罚？

## 2 每步可监控指标机制（简化为三件套）

旧版 5 字段（编号 / 命题 / 命令 / 严重程度 / 危险信号子集）→ 新版 3 件套：

| 字段 | 内容 | 失败信号 |
|------|------|---------|
| 测量命令 | 一行可复制粘贴的命令（如 `pytest tests/x.py -v`） | 命令报错或退出码非 0 |
| 期望输出 | 一句话描述「通过」长什么样（如「passed=N, failed=0, skipped=0」） | 输出含 `NaN` / `OOM` / `error` |
| 失败信号 | 列举本指标的具体失败模式（如「skipped > 0」「stderr 行数 > 5」） | 任一信号触发 = 立刻进失败 3 步闭环 |

示例（5 个，覆盖代码 / 文档 / 调研三类任务）：

- 代码（测试通过）：`pytest -v` / `passed=N, failed=0` / `failed > 0` 或 `skipped > 0`
- 代码（无 NaN）：`grep -E "NaN\|inf" train.log` / 无输出 / 任一行命中
- 文档（行数限制）：`wc -l short_prompt_plan.md` / 输出 ≤ 200 / 输出 > 200
- 文档（全中文）：`grep -nE "[A-Za-z]{4,}" plan.md` / 仅含专名 / 含未翻译英文长串
- 调研（来源数）：`grep -c "URL:" soldier_action.md` / ≥ 30 / < 30

## 3 每步反思机制（简化为 2 轮自问自答）

每次监控后立刻在流水文件追加：

```
[反思 主题] HH:MM UTC | 一轮自问：<具体问题> → 一轮自答：<具体答案>
                  | 二轮自问：<挑战上一轮，如「真考虑全了吗 ?」> → 二轮自答：<答案>
                  | 结论：无疑虑 / 仍有疑虑 → 触发动作：<下一步>
```

骨架去掉冗余引导语，只保留「问 → 答 → 挑战 → 答 → 结论 → 动作」六格。

## 4 错误学习永不再犯机制（**手动 memory，v2 不加 hook**）

[事实] 现有 `~/.claude/settings.json` 仅 1 个 PostToolUse=Bash 调试 logger hook（与 memory 无关）；v1 没有 memory 相关 hook 也运行良好。v2 沿用此最小化原则。

- **violations.md 条目 schema**：`### W-XXX：违规名称` + 「行为」+「后果」+「正确做法」+ 必含 `tags: [<标签 1>, <标签 2>, ...]` 行（常用标签 `scope-creep` / `over-design` / `language-violation` / `concept-confusion` / `flow-skip` / `memory-blind`）。
- **lessons.md 条目 schema（v3 三审新增，与 violations.md 对称）**：`### L-XXX：教训名称` + 「正确行为」+「教训」+「特化例子」+ 必含 `tags:` 行（常用标签同上）。
- **迁移规则（v3 三审新增）**：现有 lessons.md / violations.md 迁移到 v2 时必须全条目带 `tags:` 行；未带 `tags:` 的旧条目不计入 session 开头自检覆盖（grep `tags:` 时被自然排除），需先补齐 `tags:` 才能恢复覆盖。
- 错误发生时：下士/列兵手动追加一条到 `content/memory/violations.md`（按上述 W-XXX schema）。
- session 开头：下士/列兵按 `tags:` 字段 grep 自检（避免自由文本漏检）：`grep -E "tags:.*<本任务相关标签>" content/memory/violations.md content/memory/lessons.md`；命中则在流水文件写「[历史教训] W-XXX 已查阅」。
- **强制收尾二选一（v3 二审新增 + 三审完善）**：每次任务结束（写 corporal_action.md / soldier_action.md 末段时），下士/列兵必须二选一：(a) 在 `content/memory/violations.md`（按 W-XXX schema）或 `content/memory/lessons.md`（按 L-XXX schema）追加新条目（含 `tags:`）；(b) 显式写「[无新增教训] 本任务无新违规也无新经验」。**不写 = 失职雏形**（让「项目越运行越强」从「有人勤快才会强」回到强制闭环）。
- **不加 hook**：v2 不引入 Stop hook、不引入 spool、不引入 compactor、不引入 flock；保留现有 PostToolUse=Bash background logger 调试 hook（`set_claude.sh` 现有逻辑不动）。未来增强（如自动化 spool + compactor）走另一份独立提案，仅在指挥官明确批准后单独提议，不在本 v2 范围。

## 5 memory 顶级架构维度（**单一规范目录 + 双工具加载契约**）

### 5.1 两层级（机制层 vs 用户层）

| 层级 | Claude Code | Codex CLI | 谁写 | 何时加载 |
|------|------------|-----------|------|---------|
| 机制层（工具内置自动记忆） | `~/.claude/projects/<encoded-cwd>/memory/MEMORY.md`（≤ 25 KB 自动注入；要求 v2.1.59+（仅机制层 auto memory 需要；本 v2 用户层方案不依赖）；与本仓库用户层 memory **不混用**）[事实/SEARCH 16] | `~/.codex/memories/`（≤ 5000 token 注入；experimental；EU/UK/CH 启动期不可用）[事实/SEARCH 17 + FETCH 1] | AI 自己 | 每 session 开头 |
| 用户层（仓库内 memory） | 经 `repo/CLAUDE.md` 顶部明文「需要时 Read content/memory/INDEX.md 找需要的细则」（**不**用 `@` 自动导入） | 经 `repo/AGENTS.md` 顶部明文「请 Read content/memory/INDEX.md」指令；**不依赖** `~/.codex/AGENTS.md` 全局机制 | 用户写（AI 读） | 按需 grep / Read |

### 5.2 单一规范目录 + 双工具加载契约（取代旧三共享方案）

**单一规范目录** = `<repo>/content/memory/`（双工具读的同一份；不在用户级目录 `~/.claude/memory` 或 `~/.codex/memory` 放副本，因为这两个路径 **不是** 任一工具的官方自动加载入口，把软链接指过去工具不会自动读）。

| 工具 | 官方加载入口 [事实] | 本方案如何对接 |
|------|------------------|--------------|
| Claude Code | repo 根 `CLAUDE.md`（启动时注入）+ `@<相对路径>` import 语法 + `--add-dir` CLI 标志 [事实/SEARCH 16] | repo 根 `CLAUDE.md` 顶部明文写「需要时 Read content/memory/INDEX.md 找需要的细则」（**不**用 `@<相对路径>` 自动导入语法指向 INDEX.md — 让 INDEX.md 严格归磁盘语料预算，启动注入面仅 CLAUDE.md ≤ 8 KB） |
| Codex CLI | repo 根 `AGENTS.md`（启动时注入；上限 32 KiB）+ 可选 `project_doc_fallback_filenames` 让 `CLAUDE.md` 也被认作 project doc [事实/codex 实测 0.128.0] | repo 根 `AGENTS.md` → 软链接到 `CLAUDE.md`（同一份内容）+ 顶部明文「请 Read content/memory/INDEX.md 找需要的细则」+ `~/.codex/config.toml` 写 `project_doc_fallback_filenames = ["CLAUDE.md"]` 兜底 |

**关键澄清 1（v3 二审修订）**：v2 选「按需 Read」而非「自动导入」，让 `content/memory/` 严格归磁盘语料预算（## 7 第二类，≤ 50 KB），启动注入仅 `CLAUDE.md` ≤ 8 KB；INDEX.md 不能同时「启动自动导入」+「按需 Read」，二者择一，本 v2 选后者。

**关键澄清 2**：软链接 `AGENTS.md → CLAUDE.md` 仅是「让两份文件内容相同」的省事手段，工具读它是因为 **它在 repo 根** 而不是因为它是软链接；不要把「软链接存在」误说成「工具会自动读」。Claude 机制层 auto memory（`~/.claude/projects/<id>/memory/`）和 Codex 机制层 `~/.codex/memories/` 走各自工具自己的机制，**与本仓库用户层 memory 不混淆、不互通**。

### 5.3 部署前体检 + 降级路径（解决 MAJOR 3；**v2 不加 memory 相关 hook**）

**关键约束（v3 三审修订）**：体检项分三类 — (i) **硬性检测**（脚本可解析，失败 `exit 1`）(ii) **可降级**（失败时自动走兜底路径继续部署，不阻断）(iii) **信息性提示**（仅打印给指挥官看，不作为脚本分支条件）。软链接能力为可降级项 — 失败时复制副本继续部署，不阻断。Claude 版本为信息性项 — 仅打印升级建议，本 v2 用户层方案不依赖该版本。

`set_claude.sh` 和 `set_codex.sh` 部署前跑下表体检：

| 体检项 | 类别 | 检测命令 / 通过条件 | 失败处理 |
|------|------|------------------|---------|
| `ln` 命令存在 | 硬性 | `command -v ln` 退出码 0 | `exit 1` + 提示「需安装 coreutils」 |
| 软链接能力 | 可降级 | `ln -s` 测试在 repo 内能创建符号链接 | 自动 `cp CLAUDE.md AGENTS.md` 复制副本继续部署（实质降级，不 `exit 1`），README 警示 Windows |
| Claude 版本 | 信息性 | `claude --version` 解析输出 | 仅打印「建议升级到 v2.1.59+ 以启用未来机制层 auto memory；本 v2 用户层方案不依赖该版本」；不作为脚本分支条件 |
| Codex memories（experimental） | 信息性 | 跑 `codex features list 2>&1 \| grep -i memories` 打印输出（如本机 0.128.0 实测 `memories experimental false`）；**不**作为脚本分支条件 | 仅打印；v2 不依赖此特性，无须额外操作 |
| Codex EU/UK/CH 区域 | 信息性 | 打印「如在 EU/UK/CH 启动期使用，`features.memories` 不可用」提示 | 仅打印；v2 不依赖此特性，无须额外操作 |

**v2 不写入** `autoMemoryEnabled` / `[features] memories = true` / `[features] codex_hooks = true` / 任何 Stop hook；保留现有 PostToolUse=Bash 调试 logger（与 memory 无关）。机制层 auto memory 是工具自带能力，本 v2 既不主动开启也不主动关闭，留待未来单独提案。

## 6 v2 文件清单（repo-root router 架构）

```
<任意目标仓库>/                                  # 双工具都从 repo 根加载，不再依赖 ~/.codex/AGENTS.md 全局机制
├── CLAUDE.md                                    # 启动注入；≤ 8 KB（含 wc 校验，超即 exit 1）
├── AGENTS.md → CLAUDE.md                        # 软链接（Codex 读它；无软链接能力时降级为复制副本，与 ## 5.3 体检表对应）
├── content/                                     # 单源（按需读、不常驻上下文）
│   ├── memory/                                  # 用户层共享语料；磁盘语料预算 ≤ 50 KB（推荐每文件 ≤ 10 KB）
│   │   ├── INDEX.md                             # ≤ 50 行 / ≤ 2 KB；每文件一句话 + grep 关键词
│   │   ├── lessons.md                           # ≤ 250 行 / ≤ 10 KB（合并旧 reward + 正面教材）
│   │   ├── violations.md                        # ≤ 250 行 / ≤ 10 KB（合并旧 warning + W-XXX）
│   │   ├── workflows.md                         # ≤ 250 行 / ≤ 10 KB（合并旧 rules/2 + rules/3）
│   │   └── soldier_protocol.md                  # ≤ 250 行 / ≤ 10 KB（合并旧 rules/4 + 5 + 6）
│   └── templates/                               # 运行时档案骨架（双工具共享单源；详见 ## 9）；init_corporal.sh / init_soldier.sh 复制此目录到 militar_camp/
├── set_claude.sh / set_codex.sh                 # 部署脚本：体检 + 降级（## 5.3）+ wc 校验；不加 memory hook
└── militar_camp/                                # 项目级战时档案（不动）
```

`~/.codex/config.toml` 仅写 `project_doc_fallback_filenames = ["CLAUDE.md"]`（fallback 兜底）；`~/.claude/settings.json` **保持现状**（仅现有 PostToolUse=Bash 调试 logger，不增 memory 相关字段）。

**删除**：`content/system_override.txt`（指挥官明确点名）+ `content/rules/` 7 文件（合并入 `content/memory/`）。**保留**：`set_claude.sh` + 新增 `set_codex.sh` 共享 `content/` 单源；现有 PostToolUse=Bash background logger 调试 hook 不动。

## 7 字节预算（拆两类，三处口径统一）

**当前测量**[事实/列兵5 STEP 5 wc 输出]：`content/CLAUDE.md` = 406 行 / 27147 字节；`content/rules/` 7 文件 = 734 行 / 45163 字节；合计 1140 行 / 72310 字节。

| 类型 | 字节上限 | 适用文件 | 来源 [事实] |
|------|--------|---------|----------|
| **启动注入预算**（每会话自动加载到上下文） | CLAUDE.md / AGENTS.md ≤ 8 KB | repo 根 `CLAUDE.md`、软链接 `AGENTS.md` | Anthropic 官方建议 < 200 行；Codex 全局 AGENTS.md 建议 < 2-3 KB（项目级放宽到 8 KB）[SEARCH 31] |
| 同上 | Claude 机制层 `MEMORY.md` ≤ 25 KB | `~/.claude/projects/<id>/memory/MEMORY.md` | Claude 文档 25 KB 截断 [SEARCH 16] |
| 同上 | Codex project doc 总量 ≤ 32 KiB | `AGENTS.md`（含 import 展开） | Codex `project_doc_max_bytes = 32768` 默认 [FETCH 3] |
| **磁盘语料预算**（按需读，不常驻） | `content/memory/` 总和 ≤ 50 KB（推荐每文件 ≤ 10 KB / ≤ 250 行） | `INDEX.md` / `lessons.md` / `violations.md` / `workflows.md` / `soldier_protocol.md` | 工具层无硬上限；50 KB 是「便于 grep 与人审」的工程约束 |

**瘦身比**：启动注入面 72 KB → 8 KB（CLAUDE.md/AGENTS.md），磁盘语料面 ≤ 50 KB（按需 grep）。`set_*.sh` 部署前必跑 `wc -c CLAUDE.md`，> 8192 字节直接 `exit 1`。

**简化六手段**：
1. 三连复读「军法如山，错误就是死」→ 一句（详见 ## 8 修改 1）
2. 全大写 `NEVER` / `MUST` → 「rule + because」格式（Anthropic 4.x 官方建议 [SEARCH 18]）
3. 4 步 workflow 长描述（军令六现 700 字）→ 5 行骨架，详细规则进 `content/memory/workflows.md`
4. 列兵铁律 (A)~(G)（现 ~150 行）→ 5 行骨架，详细规则进 `content/memory/soldier_protocol.md`
5. 双格式：`<critical>` / `<identity>` / `<recency>` XML 标签 + markdown 二级标题镜像（Claude 吃 XML，Codex 吃 markdown）
6. 删除装饰性边框注释（`# █████████...` 不增信息）

## 8 修改前后整段对照举例（≥ 3 处；修改后行数 ≤ 修改前）

### 修改 1：三连复读 → 一句

**文件**：`content/CLAUDE.md` 底部 `<recency>` 段尾 L402-405（修改前 5 行 → 修改后 3 行，**严格更短**）

**修改前**：
```
军法如山，错误就是死。
军法如山，错误就是死。
军法如山，错误就是死。

</recency>
```

**修改后**：
```
军法如山，错误就是死。

</recency>
```

**修改原因**：三连复读基于「重复指令 47 胜 0 负」研究，但同段已有 `<recency>` 标签 + 上下文已多次重申，三连边际收益≈零却消耗 token。详细 because + 来源已移入 `content/memory/lessons.md` 的「为何砍掉三连复读」条目（启动注入文件不放解释，符合 MINOR 1 修订）。

### 修改 2：列兵铁律 (A)~(G) → 5 行骨架 + 路由

**文件**：`content/CLAUDE.md` L195-238（修改前 44 行 → 修改后 2 行，**严格更短**）

**修改前**（节选 L195-202 + L235-237，共 44 行）：
```
(A) 实时汇报（最重要）：
    - 第一步：调用 bash __CLAUDE_CONFIG_DIR__/init_soldier.sh <下士编号> <列兵编号> <工作目录>，然后在生成的 soldier_status.md 填写本 prompt 全文 + 派出时间 + 授权字段。
    - 每完成一个步骤，立刻（不超过 30 秒）写入 soldier_action.md
    - 30 秒无写入且无 [SILENCE_START] = 叛国 = 下士立刻处决
... (B) 沉默申报 (C) BOARD_READ (D) 禁改 config (E) 先记录再操作 (F) 真实性 ...
(G) 自主执行权（仅在 soldier_status.md「授权字段」明确写明时生效）：
    - 默认：每步必须请示下士/指挥官；授权时可自主试方案；错 3 次必须回报；自主权不解除记录义务和真实性协议
```

**修改后**：
```
列兵铁律 5 条骨架：(A) 到岗即调 init_soldier.sh + 30 秒内写一步 (B) blocking 才能 SILENCE 申报 (C) 每轮开头 BOARD_READ (D) 未经授权禁改 config / 性能代码 (E) 先记录再操作 (F) 全中文 + [事实]/[推论]/[假设] 标注 (G) 默认请示，授权字段明示才有自主权（错 3 次回报）。
详细规则 + 范例 → Read `content/memory/soldier_protocol.md`。
```

**修改原因**：旧版 44 行常驻主指令文件每个 session 被双工具全文加载消耗 ~2 KB；30 秒计时器 / 沉默格式 / 自主权例子极少触发却常驻。骨架命中关键词 + 路由到 memory；指挥官原话「让 AI 意识到有这么一个东西然后去读就行」即是此意。

### 修改 3：rules/ 7 文件 → memory/ 5 文件合并

**文件**：`content/rules/` 整目录 → `content/memory/`（修改前 734 行 / 45163 字节常驻启动注入；修改后磁盘 ≤ 1050 行但**单次 grep 只读 1 个文件 ≤ 250 行**、启动注入面归零，**严格更短**）

**修改前结构**：见旧版 plan L173-181（7 文件按功能编号划分）。**修改后结构**：见 ## 6 文件清单段 `content/memory/` 子树（5 文件按思考阶段划分）。

**修改原因**：旧 7 文件按「功能编号」划分，调研任务常需 Read 3 个；新版按「思考阶段」划分（教训 vs 违规 vs 做事 vs 派兵），单次任务通常 Read 1 个；`INDEX.md` 极薄让 AI 5 秒决定该 Read 哪个。**关键：磁盘 50 KB ≠ 启动注入 50 KB** — 启动注入面仅 `CLAUDE.md` ≤ 8 KB，其他按需 Read，符合 ## 7 双预算。

## 9 templates 处理（双向去重 + 不强制行数 + 多轮反思 + 功能保留 + set_codex 共享）

**现状**[事实/列兵5 STEP 5 wc + 列兵 9 重测]：`content/rules/templates/` 9 文件 = 591 行 / 28 KB；`init_corporal.sh:10` + `init_soldier.sh:18` 都硬编码 `TEMPLATE_DIR="$HOME/.claude/rules/templates"`；7 个 templates 被两脚本 cp/sed 使用（warning + reward + traitor + README + 3 corporal + 2 soldier），剩 1 个 `corporal_situation.md` 由 init_corporal.sh sed。

### 9.1 双向去重检查表（每文件 ≥ 2 轮反思见 `corporal_2/number9/soldier_action.md` STEP 4-15）

| 文件名 | 现状 | 跟 v2 其他文件重复（正向）+ 反向迁移检查 | 处理决定 | 不可压理由（保留部分） |
|------|------|----------------------------------|---------|--------------------|
| warning_board.md | 136 行 / 6.3 KB | 正向：W-001~W-010 详细 = memory/violations.md（W-XXX schema 单源）；沉默申报格式 = memory/soldier_protocol.md。反向：无 | **简化** | 「强制阅读声明 + [BOARD_READ] 写入格式」骨架（运行时模板靠它定锚）+ 项目特化空段 + 观察名单空表 |
| traitor.md | 105 行 / 4.5 KB | 正向：法典速查 + 列兵管理铁律 + 沉默申报 = memory/violations.md + memory/soldier_protocol.md；L6「system_override.txt」是死链（v2 已删该文件）。反向：无 | **简化 + 修死链** | 5 张空表（列兵记录 / 首级展示台 / 叛徒名单 / 观察名单 / 正面教材，运行时填）+ L6 改「完整版见 content/memory/violations.md 与 soldier_protocol.md」 |
| soldier_action.md | 73 行 / 3.9 KB | 正向：4 步 workflow 范例 = memory/workflows.md；3 段 HTML 注释批注 = 主路由 CLAUDE.md + memory/soldier_protocol.md。反向：无 | **简化** | [STEP 0] [BOARD_READ] 模板（每次回复第一条防伪占位）+ [STEP 1] 通用条目骨架（操作 / 结果 / 标注） |
| reward_board.md | 68 行 / 3.1 KB | 正向：R-001~R-010 详细 = memory/lessons.md（L-XXX schema 单源）。反向：无 | **简化** | 「强制阅读声明 + [BOARD_READ] 写入格式」骨架（与 warning_board.md 镜像）+ 项目特化空段 |
| README.md | 56 行 / 2.4 KB | 正向：使用规则 L29-32 4 处 `~/.claude/rules/1/3/4/5_*.md` = v2 已删的死链；写入规则 + 强制阅读 = 主路由 CLAUDE.md + memory/workflows.md。反向：无 | **简化 + 修死链** | 一句目录结构 ASCII 树（运行时 `ls militar_camp/` 一眼看懂）+ 一行索引「详见 content/memory/INDEX.md」 |
| corporal_status.md | 46 行 / 2.8 KB | 正向：填写规则 + 豁免 = memory/workflows.md（4 步 workflow 第 1 步）。反向：无（运行时档案专用） | **简化** | 编号 + 接任时间字段 + 指挥官命令原文段 + 状态段 + 观察项清单 5 字段表头 + 3 行示例（运行时填写锚点） |
| soldier_status.md | 45 行 / 1.3 KB | 正向：3 处 HTML 注释批注 = 主路由 CLAUDE.md + memory/soldier_protocol.md。反向：无（运行时档案专用） | **简化** | 编号 / 派出时间 / 状态字段 + 授权字段段（W-008 verbatim 防控点）+ Agent prompt 全文代码块（W-008 防摘要）+ 最终状态字段 |
| corporal_action.md | 43 行 / 3.5 KB | 正向：4 步 workflow 范例 = memory/workflows.md；12 行 HTML 注释 = 主路由 CLAUDE.md + memory/violations.md（三件套）。反向：无 | **简化** | 一句格式说明（时间戳 + 执行了什么 + 发现了什么）+ 「## YYYY-MM-DD HH:MM UTC — 接任 + 摸清需求」首条骨架（init_corporal.sh sed 后的运行时锚点） |
| corporal_situation.md | 19 行 / 0.2 KB | 正向：无（已最小）。反向：无（运行时战况档案专用） | **保留（不动）** | 已是最小可用骨架（4 段空白：好/坏/焦点/已派列兵表）；任何删减让 BOARD_READ 时无法一眼看到 4 段 |

**不强制总行数目标**[指挥官原话]：「不一定是要从多少行变成多少行 ... 反思多次确定能压缩的东西就压 不能压缩就不压缩」。每文件按上表反思决定，不机械算总和。

**9.2 set_codex 是否需要 templates**：双工具共享同一份 templates，set_codex 不单独部署。理由：militar_camp/ 战时档案骨架与具体工具无关（谁运行 init_corporal.sh 都需要相同骨架），符合 v2 整体「单源 content/」原则（## 5.2 + ## 6）；新位置 `<repo>/content/templates/`（与 `content/memory/` 平级）。
**9.3 init_*.sh 部署路径调整**：`init_corporal.sh:10` + `init_soldier.sh:18` 当前 `TEMPLATE_DIR="$HOME/.claude/rules/templates"`（绑死 set_claude.sh 安装路径）→ v2 改为「相对调用所在 repo 根定位」：在 init_*.sh 顶部加 `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; TEMPLATE_DIR="$REPO_ROOT/content/templates"`（脚本本身复制到目标仓库的位置由 set_*.sh 决定）；`set_claude.sh` + `set_codex.sh` 部署时把 `content/templates/` 整目录复制到目标仓库（与 `content/memory/` 一并）。
**9.4 功能保留验证 + 最小 templates 集**：init_*.sh 部署后必须存在的 9 文件（缺一即 init 失败）= `warning_board.md` / `reward_board.md` / `traitor.md` / `README.md` / `corporal_status.md` / `corporal_action.md` / `corporal_situation.md` / `soldier_status.md` / `soldier_action.md`（文件名不变，仅内容简化）；验证方式：`set_*.sh` 部署后跑 `bash init_corporal.sh /tmp/test_workdir` 跑通；预期产物 `militar_camp/` 含 4 共享文件 + `corporal_1/` 三件套；缺任一文件或 sed 失败即 `exit 1`；运行时 `[BOARD_READ]` 写入格式骨架仍可被 AI 直接抄；4 步 workflow 第 1 步落地处（`corporal_status.md` 观察项清单 5 字段表头 + 3 行示例）仍可填。

## 完工说明

8 章节 + ## 9 templates 处理 + 双预算（启动注入 ≤ 8 KB / 25 KB / 32 KiB；磁盘语料 ≤ 50 KB）+ 修改前后对照 3 处（后 ≤ 前）。**codex 三审 4 项（已修订）**：BLOCKER 1 / MAJOR 1 / MAJOR 2 / MINOR 1 见 ## 4 / ## 5.1 / ## 5.3。**指挥官追加 templates 章节（## 9）**：双向去重 9 行表 + 9 文件 × 2 轮反思（见列兵 9 流水）+ set_codex 共享单源 + init_*.sh 改 REPO_ROOT 相对路径 + 最小 templates 集 + 验证方式。等指挥官批准后由下一名列兵实施。
