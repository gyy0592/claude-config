# {{PROJECT_NAME}} 可维护性化简 — Draft 模板

> 本模板用于对**任意**代码仓库做"可维护性优先、行为不变"的化简重构。
> 实例化方法：把所有 `{{...}}` 占位符替换成项目具体值；删除未启用的可选段落；保留所有 [HARD RULE] 标记的条目。
>
> 占位符清单（实例化前必须全部填完或显式标注 `⚠ not specified`）：
> - `{{PROJECT_NAME}}` — 项目代号
> - `{{REPO_PATH}}` — 仓库绝对路径
> - `{{LANGUAGE}}` — 主要语言（Python / C++ / ...）
> - `{{ENTRY_SCRIPT}}` — 复现入口脚本（基准跑这个）
> - `{{BASELINE_CMD}}` — 跑出基准输出的命令
> - `{{BASELINE_OUTPUT_DIR}}` — 基准输出落盘目录
> - `{{KNOWN_EXTERNAL_FUNCS}}` — 已知外部函数家族列表（如 km 系列）
> - `{{PROTECTED_BLOCKS}}` — 黑名单：禁止改动的代码块/文件（GPU kernel / Triton / cython / 第三方编译模块 ...）
> - `{{ASK_TOOLS}}` — 启动时由用户从 {ask-claude, ask-gemini, ask-codex, ...} 中选定的工具集
> - `{{ASK_TOOL_SCRIPT_DIR}}` — 上述 ask-* 工具对应 shell 脚本的绝对目录（humanize plugin 通常在 `~/Programs/humanize/scripts/` 或 `~/.claude/plugins/cache/PolyArch/humanize/<ver>/scripts/`）。subagent 必须 **Bash 直调**这些脚本，不能通过 Skill tool 调用——后者只返回 driver inline 不真执行模型（2026-04-27 实测）
> - `{{PERF_MONITOR_INTERVAL_SEC}}` — 运行时资源监控打印周期（默认 5）
> - `{{REPORT_DETAIL_REF}}` — 报告颗粒度参考样例文件路径
> - `{{ROUND_AGENT_COUNT}}` — 每轮并行 subagent 数量（推荐 5–10）

---

## Goal

对 `{{REPO_PATH}}` 做轮次化、并行化的可维护性化简。每一轮在**严格保留运行时行为**的前提下：合并重复实现、提取硬编码到 yaml config、清除无用代码与文件、用数学等价的更短实现替换冗长实现、删除冗余防御性代码（让真正错误直接暴露）。重构后的代码必须**输出与原版完全一致**（仅允许浮点运算顺序导致的舍入误差），且**运行时性能不低于原版**。每轮完整收敛——直到再扫描不出任何候选——为止。

---

## Constraints

### A. 行为保留合约 [HARD RULE]
1. **输出等价**：原版与改版对相同输入必须产生**相同输出文件**。容忍上限：浮点运算顺序差异带来的舍入误差。超出 = 拒绝合入。
2. **性能不退化**：改版总运行时间 ≤ 原版（同机同输入）；GPU 显存峰值、CPU 占用峰值不得增加。监控方式：在 `{{ENTRY_SCRIPT}}` 中嵌入每 `{{PERF_MONITOR_INTERVAL_SEC}}` 秒打印 `nvidia-smi`（若用 GPU）+ `psutil` CPU/RSS 的轻量探针，**用 Python 代码周期性打印**，不依赖外部脚本。
3. **bug 不修**：若发现原代码确有 bug，**当前轮仍必须复现该 bug 的原始输出**，仅在根目录 `real_bug.md` 中记录（位置/触发条件/正确行为应为何）。修复留待后续独立任务。
4. **外部函数输入冻结**：任何在仓库内找不到定义的函数（含 `{{KNOWN_EXTERNAL_FUNCS}}` 及扫描中新发现的），其调用点的**输入参数语义、类型、坐标空间必须 100% 不变**。需在根目录 `unknown_funcs.md` 累积记录每个外部函数的：调用点、输入类型、输入语义（含坐标系/单位/约定）、输出类型、输出语义。

### B. 优化方向 [HARD RULE]
5. **硬编码 → yaml**：可参数化的常量（数值阈值、路径、超参）全部抽到 `config/*.yaml`，代码侧只读 config。
6. **重复合并**：逻辑相同仅命名/注释不同 → 必须合并；近乎相同但差异可由参数覆盖且不增加复杂度 → 必须合并。判定由 agent 自行做，标准是"合并后更易读且不引入新分支炸弹"。
7. **死码清除**：未被任何调用图触达的函数、模块、文件、import 一并删除。
8. **数学等价化简**：长冗实现若存在数学等价的更短形式，替换。前提仍是 A.1 输出等价。
9. **删冗余防御性代码**：包裹"绝不会失败"路径的 `try/except`、`if x is not None: x.method()` 之类反复保险的样板 → 删除，让真正的异常直接抛出并暴露 bug。例外：跨进程/IO 边界、用户输入边界保留。
10. **保护黑名单**：`{{PROTECTED_BLOCKS}}` 中的代码（含但不限于现成 GPU/CUDA/Triton kernel、cython、第三方预编译模块）一律**不得修改**，连重排参数顺序都不允许。

### C. 每次修改的双通过门 [HARD RULE]
11. **ask 工具脑内对比**：对每个修改点，agent 必须从 `{{ASK_TOOLS}}` 中至少调用一个工具，**调用方式必须是 Bash 直调对应 shell 脚本**：`bash {{ASK_TOOL_SCRIPT_DIR}}/ask-<tool_name>.sh "<完整 prompt>"`。**禁止通过 Skill tool 调用 humanize:ask-***——humanize plugin 当前的 Skill tool 集成只返回 driver 文档不真执行模型（2026-04-27 minimal-unit eval 实测）。喂入的 prompt 必须包含「原始函数 + 修改后函数 + 调用上下文 + `unknown_funcs.md` 中相关条目」，要求逐行推理两者输入输出是否等价；完整推理链落盘到 `mindtest/<修改标识>.md`。Prompt 含 inner `"` 或 `{}` 的大段源码时，建议先写到临时文件，再用 `bash {{ASK_TOOL_SCRIPT_DIR}}/ask-<tool_name>.sh "$(cat /tmp/prompt.txt)"` 形式喂入，避免 shell 引号转义出错。
12. **独立测试脚本（函数级 OLD vs NEW，禁止 full-pipeline 冒充）**：每个修改点对应一个独立测试脚本（位置：`tests/simplify/<修改标识>_test.py`），**仅对被修改函数本身做 OLD vs NEW 对比**。测试 input 必须是该函数的**直接调用参数**（不是 pipeline 入口的 sample 输入），通过以下任一方式获取，并在脚本 docstring 里说明 input 来源：
    - (a) 静态阅读该函数所有调用点代码，推断 input args 的 dtype / shape / 值域 / 坐标系 / 单位 / 约定；
    - (b) 在原 baseline 跑期间用 hook / monkey-patch 在该函数 entry 处 dump 真实 input args 落盘到 `tests/simplify/fixtures/<修改标识>.npz`，测试 load 进来；
    - (c) 用代码上下文里已有的 fixture / sample 数据。
    
    OLD 与 NEW 在按 dtype `np.allclose`（容差表见 baseline manifest）一致即通过。脚本永久保留作为回归证据。
    
    **禁止该测试脚本调用 `{{BASELINE_CMD}}` / 全 pipeline 入口 / 任何 stage runner** —— per-modification 测试与 round-end 全量重跑是两个层级，不允许冒充。验证粒度强制三层（详见下条 C.12.bis）。

12.bis. **验证粒度分层 [HARD RULE]**：simplify 等价验证强制分三层，AC 与 task 起草必须按层归类，**禁止跨层冒充**：
    - **Tier 1（per-modification 函数级，C.12）**：每改一个函数立即跑 `tests/simplify/<id>_test.py`，秒级完成；OLD vs NEW 在该函数直接 input args 上做 `np.allclose`。粒度细，定位精确，不依赖 pipeline。
    - **Tier 2（round-end 全 pipeline）**：每轮关闭前一次 `{{BASELINE_CMD}}` 全 pipeline 重跑，对照 round-0 baseline manifest，覆盖 `{{BASELINE_OUTPUT_DIR}}`。粒度粗，验证整体合规，单次耗时长。
    - **Tier 3（用户里程碑）**：用户指定关键节点（如最终签收前最后一轮）追加一次 Tier 2 全量重跑。
    
    **禁止把 Tier 1 写成 Tier 2/3 的措辞**（如"每次 refactor 合入后重跑 `{{BASELINE_CMD}}`"）— 这是 plan/AC 起草时反复出现的语义错误，会让每次小改都触发数小时的全 pipeline 跑，工程不可行且定位粒度错。AC 描述若把 per-modification 等价的 positive test 写成全 pipeline 重跑 = 起草错误，必须修正。
13. **写盘前提**：测试脚本通过 **AND** mindtest 推理结论为"等价" 同时满足才允许覆盖原文件。任一失败 → 立即拒绝、回滚、log 到 `task_<round>/log-fail-method.md`。
14. **原地覆盖，无 backup 目录**：版本回溯一律走 git。

### D. 工程纪律 [HARD RULE]
15. **反震荡**：第 N 轮把构造 A 改为 B 后，第 N+1 轮不得在没有文档化理由（写入 `report/run{N+1}_review.md`）的情况下再把 B 改回 A。无理由的回退被主线程阻断。
16. **subagent prompt 完整传递**：派发给每个 subagent 的 prompt 必须**逐字包含本 Constraints 全部条目**（A–F），不得缩写、不得省略、不得"参见 draft"。理由：subagent 没有跨轮记忆。
17. **语义定位**：所有"在哪里改"的描述必须用函数名 / 逻辑块名 / 调用关系 / 数据流位置。**禁止使用行号**——编辑后即失效。
18. **代码片段不入 plan**：`artifacts/_project/plan.md` 与本 draft 只描述**做什么/为什么**，不出现具体代码 / yaml / class 名称。

### E. 并行与监控 [HARD RULE]
19. **每轮 `{{ROUND_AGENT_COUNT}}` 个 agent 并行**：扫描产出候选清单后，按模块/文件/独立函数族切分给 agent。切分原则：各 agent 输入/输出合约不重叠，互不踩。
20. **agent 自包含**：每个 agent 内部完成「修改代码 → 调 ask 工具 → 写测试脚本 → 跑测试」全流程；不得把任何一步外抛回主线程。
21. **主线程仅监控**：主线程只校验 agent 产出（测试日志存在且 PASS / mindtest 文件存在且结论等价 / 没有跳过任何步骤）。校验失败立即重新派发同任务，不自己接手执行。

### F. 启动询问 [HARD RULE]
22. **第 0 步 AskUserQuestion**：在执行任何步骤前，必须用 `AskUserQuestion` 一次性向用户收齐：
    - 选用哪些 ask 工具（多选）→ 落入 `{{ASK_TOOLS}}`
    - ask 工具的 shell 脚本目录 → 落入 `{{ASK_TOOL_SCRIPT_DIR}}`（默认探测 `~/Programs/humanize/scripts/` → `~/.claude/plugins/cache/PolyArch/humanize/<ver>/scripts/`）
    - `{{ENTRY_SCRIPT}}` 与 `{{BASELINE_CMD}}`
    - `{{BASELINE_OUTPUT_DIR}}`
    - `{{PROTECTED_BLOCKS}}` 黑名单
    - `{{PERF_MONITOR_INTERVAL_SEC}}`（默认 5）
    - `{{ROUND_AGENT_COUNT}}`（默认 8）
    - `{{REPORT_DETAIL_REF}}` 颗粒度参考样例（若无，主线程在第 1 步生成）
    用户未答的项 → 全部标 `⚠ not specified` 暂停，不得自行假设默认值。

### G. 破坏性操作守门
23. 原地文件覆盖：仅在 C.13 双通过后允许。
24. 删除文件 / 大段删码：subagent 必须先在 `report/run{X}_review.md` 中说明该文件/代码无任何调用方（附扫描证据），再执行。

---

## Inputs

- `{{REPO_PATH}}` 下所有源文件——重构目标。
- 原始基准产物：用 `{{BASELINE_CMD}}` 在干净 commit 下跑一次得到的 `{{BASELINE_OUTPUT_DIR}}` 完整快照——所有后续等价比对的"金标准"。
- `unknown_funcs.md`、`real_bug.md`——首轮空文件，跨轮累积。
- `{{REPORT_DETAIL_REF}}`——报告颗粒度的参考样例。

## Outputs

**每次修改产生**：
- 修改后的源文件（原地覆盖）
- 独立测试脚本：`tests/simplify/<修改标识>_test.py`，原 vs 新对比
- `mindtest/<修改标识>.md`：选定 ask 工具的逐行等价推理记录

**每轮（run_X）产生**：
- `loop_to_fix/run_X.md`——本轮全量扫描候选清单（含语义位置 + 优化类型 + 合并/删除理由）
- `report/run{X}_review.md`——本轮所有动作的高→低叙述：先讲本轮整体动机与抽象目标，再逐项讲每个修改的具体代码层动作；颗粒度对齐 `{{REPORT_DETAIL_REF}}`

**跨轮持久维护**：
- `unknown_funcs.md`——外部函数合约累积
- `real_bug.md`——已识别但暂不修的 bug
- `config/*.yaml`——硬编码迁移产物，每轮新增条目

---

## Environment & Resources

- 工作目录：`{{REPO_PATH}}`
- 语言：`{{LANGUAGE}}`
- 版本控制：git（首轮派发前必须确认仓库已初始化且 worktree clean）
- 禁改清单：`{{PROTECTED_BLOCKS}}`
- 已知外部函数家族：`{{KNOWN_EXTERNAL_FUNCS}}`，其余在扫描中发现并入档
- 性能监控：在 `{{ENTRY_SCRIPT}}` 嵌入 `{{PERF_MONITOR_INTERVAL_SEC}}` 秒周期探针
- ask-* 工具脚本目录：`{{ASK_TOOL_SCRIPT_DIR}}`（subagent 必须 Bash 直调，不能通过 Skill tool）
- 写盘策略：原地覆盖，过双通过门后才允许

---

## Known Facts

| 事实 | 来源 |
|------|------|
| 输出等价容忍上限为浮点舍入 | 用户陈述 |
| 性能必须 ≥ 原版（运行时 + 资源峰值） | 用户陈述 |
| GPU/Triton/CUDA kernel 一律不动 | 用户陈述 |
| bug 仅记录不修，当前输出仍复现原 bug | 用户陈述 |
| 外部函数输入完全冻结 | 用户陈述 |
| 防御性 try/except/if 在内部路径上要删 | 用户陈述 |
| humanize plugin 的 Skill tool 调 ask-* 工具返回 driver inline 不真执行；subagent 必须 Bash 直调 `{{ASK_TOOL_SCRIPT_DIR}}/ask-<tool_name>.sh` 脚本（具体目录见 Environment 段） | 2026-04-27 minimal-unit eval 实测 |

---

## Execution Order

── parallel ──
1. [independent] AskUserQuestion 收齐 F.22 全部参数；任一缺失 → 暂停
2. [independent] git 状态校验：worktree clean、HEAD 已记录
── end parallel ──

3. [depends: 1, 2] 用 `{{BASELINE_CMD}}` 在当前 HEAD 跑一次基准，归档 `{{BASELINE_OUTPUT_DIR}}` 快照与运行时 / 资源指标作为金标准

── parallel ──
4. [depends: 3] 全仓扫描所有外部调用，初始化 `unknown_funcs.md`
5. [depends: 3] 若 `{{REPORT_DETAIL_REF}}` 不存在 → 主线程生成一份样例落盘
── end parallel ──

6. [depends: 4, 5] 全仓候选扫描：合并对、硬编码、死码、数学等价化简点、冗余防御代码 → 写入 `loop_to_fix/run_{X}.md`，按模块切分为 `{{ROUND_AGENT_COUNT}}` 组

── parallel ──
7. [depends: 6] Subagent_1：处理候选组 1，执行 C 全流程
8. [depends: 6] Subagent_2：处理候选组 2，执行 C 全流程
9. [depends: 6] Subagent_3：处理候选组 3，执行 C 全流程
... [继续展开至 `{{ROUND_AGENT_COUNT}}` 个 agent]
── end parallel ──

10. [depends: 7..N] 主线程聚合校验：每个 agent 的测试 PASS + mindtest 等价结论 + 步骤完整。任一失败 → 同任务重派
11. [depends: 10] 重跑 `{{BASELINE_CMD}}` 对比 `{{BASELINE_OUTPUT_DIR}}` 与运行时/资源指标，做"全仓级"等价 + 性能不退化复核
12. [depends: 11] 写 `report/run{X}_review.md`，高→低叙述
13. [depends: 12] 反震荡审计：与历轮决策对账，标记并阻断无理由回退
14. [depends: 13] 进入下一轮，回到步骤 6，X+=1，直到扫描候选为空

---

## Observable Outputs

**每轮跟踪的标量指标**：
- 本轮处理候选数 / 实际写入修改数 / 被拒回派数
- 本轮新增 yaml config 条目数
- 本轮删除文件 / 函数 / import 数
- 本轮 `unknown_funcs.md` 新增条目数
- 本轮 `real_bug.md` 新增条目数
- 全仓重跑：耗时差（新 − 原）、显存峰值差、CPU 峰值差

**每项详细记录**：
- 修改标识、语义位置、修改类型（合并/抽 yaml/删死码/数学化简/删防御）、ask 工具结论、测试脚本路径、双通过 yes/no

**需监控的中间产物**：
- `loop_to_fix/run_{X}.md` 必须在 agent 派发前存在且非空
- 每个 subagent 触及任何外部调用前必须在其 mindtest 中显式引用 `unknown_funcs.md` 对应条目

**保存的产物**：
- 上述 Outputs 段全部文件，跨轮只追加不覆盖
- `tests/simplify/*` 永久保留作为回归基线

---

## Decision Points

| 待定项 | 选项 | 取舍 |
|---|---|---|
| ask 工具组合 | claude / gemini / codex / 其中多个 | 多个交叉验证更稳但更慢；单个快但风险集中 |
| `{{ROUND_AGENT_COUNT}}` | 5 / 8 / 10 | 多并行更快但模块切分更难，少并行更稳但耗时长 |
| 性能监控周期 | 1s / 5s / 10s | 频繁更精细但 IO 开销，稀疏更轻但易漏短峰 |
| 是否在第 0 轮强制要求用户提供颗粒度参考样例 | 是 / 否（主线程自动生成） | 用户给 → 完全对齐期望；自动生成 → 启动快但首轮可能颗粒度偏离 |
| 黑名单粒度 | 文件级 / 函数级 / 行级 | 文件级最安全；行级灵活但易踩 |

---

## 自检清单（实例化与每轮派发前各跑一次）

1. 所有 `{{...}}` 占位符已被替换或显式标注 `⚠ not specified`
2. Constraints 全部条目已逐字进入即将派发的 subagent prompt
3. Execution Order 每步都有 `[independent]` / `[depends: N]` 标签
4. 并行组用 `── parallel ──` / `── end parallel ──` 包夹
5. 没有把代码片段 / yaml 模板 / class 名写进本 draft
6. Observable Outputs 没有空项；未确认项标 `⚠ not specified`
