[🇺🇸 English](#-english) | [🇨🇳 中文](#-中文)

---

<a name="-english"></a>
# Ten Commandments for AI-Assisted Coding 🇺🇸

**#1: Plans Must Be Highly Abstract — No Implementation Details Allowed**

* **Breakdown**: The planning phase establishes only system architecture, data flow, and core steps. The AI must provide higher-dimensional abstract descriptions and maintain deliberate vagueness in the plan. Concrete code snippets or low-level API calls are strictly forbidden.
* **Rationale**: Introducing fine-grained details early creates directional bias, causing small errors to compound through subsequent steps. As long as the macro-level fuzzy plan is logically correct, even if the AI makes mistakes during code generation, it can re-read the high-level plan, detect logical conflicts, and self-correct.

**#2: Decompose Tasks into Physically and Logically Decoupled Subtasks — Execute in Dependency-Topological Order**

* **Breakdown**: Force-split large requirements into mutually independent modules. Use parallel or batch instructions to process these subtasks.
* **Execution Order Iron Law (Prerequisite-First)**:
  1. **Run the fastest, most basic validations first**: Does the data exist and is it readable? Is the network connected? Does the API return the expected format? Are all environment dependencies in place? Confirm these with minimal code (even a single curl) in seconds.
  2. **Then run main logic that depends on prerequisite results**: Only begin writing and executing primary code after all prerequisite validations pass.
  3. **Independent subtasks must run in parallel**: Annotate each step's input dependencies; if two steps have no data-flow dependency, force parallel execution.
  4. **When ordering is uncertain, ask the user**: The AI is forbidden from assuming execution order on its own. It must explicitly present the dependency graph and ask the user to confirm.
* **Anti-pattern**: Downloading a dataset online while simultaneously starting evaluation — the evaluation code depends on the dataset, creating coupling. The correct approach: independently download the dataset and verify its integrity first, then start evaluation. Meanwhile, download and API connectivity testing can run in parallel.
* **Rationale**: AI handling tightly coupled tasks easily produces "modify A breaks B" hallucinations. Decoupling is the sole physical prerequisite for safe parallelism, dramatically reducing context interference and boosting execution speed. Validating prerequisites first exposes fatal problems (missing data, broken network) in seconds, preventing the main logic from running for hours before crashing.

**#3: Force-Execute `/simplify` After Every Task Completion**

* **Breakdown**: After any feature is verified working, immediately invoke `/simplify` or an equivalent cleanup command.
* **Rationale**: AI-generated code inherently carries redundant defenses, unused variables, and excessive comments. This step enforces AST-level (Abstract Syntax Tree) refactoring, stripping dead code and maintaining high information density and minimalism in the codebase.

**#4: Maintain High-Level AI Experiment and Error Logs (for Long-Term Maintainability)**

* **Breakdown**: Force the AI to document its trial-and-error experience during development. Three types of logs are mandatory:

1. **Methodological success log**: For each optimization target, explicitly record "what action improved the result" and force the AI to briefly analyze the underlying algorithmic or logical reason. All success nodes must be recorded without omission.
2. **Methodological failure log**: Record attempted paths that led to degradation or outright failure, along with failure analysis at the algorithm or design level.
3. **Engineering error log**: Separately record pure execution-level mistakes — wrong dependency imports, assumed non-existent file paths, environment configuration omissions, or pure code logic typos.
* **Rationale**: Make the AI's trial-and-error boundaries explicit. Use historical experiment data to converge the search space, preventing the AI from repeatedly falling into the same traps across long-lived projects.

**#5: Use Structured Documents for State Handoff — Locate Code by Conceptual Description**

* **Breakdown**: Integrate Anthropic's workflow logic.

1. Code comments must never contain "development progress" (e.g., "fixed bug X"). Comments explain business logic only.
2. Never use "line number + file path" to locate targets. Use semantic, conceptual descriptions instead (e.g., "modify the core middleware responsible for user authentication").
3. Use independent, standardized text artifacts (e.g., `PROGRESS.md` or state files) to hand off context and record development progress, decoupled from conversation history.
* **Rationale**: Line numbers are extremely fragile dynamic coordinates that break easily. Concept-based descriptions give instructions far greater robustness. Separating state management from code comments and chat logs into standalone documents is the most effective mechanism against LLM "context amnesia."

**#6: Never Use `/init` — Hand-Write All Persistent Instructions (`CLAUDE.md` and System Messages)**

* **Breakdown**: Persistent instructions have two carriers with different mechanisms and purposes. Understand each:

  **1. CLAUDE.md (file-based, project/global level)**
  - Physical form: placed in the project root `CLAUDE.md` or global `~/.claude/CLAUDE.md`.
  - Loading mechanism: read once at session start and memoized (cached in memory). Every subsequent API call carries this cached content — it does not re-read the file each turn. Modifying the file mid-session does **not** hot-reload; a new session is required.
  - Use cases: project-level tech stack constraints, naming conventions, forbidden behaviors, long-lived engineering rules.

  **2. System Message (API/platform-based)**
  - Physical form: explicitly passed via the `system` field in API calls, or set in the Claude.ai platform's Project "System Prompt" configuration.
  - Loading mechanism: **explicitly carried with every API request**, using Anthropic prompt caching to avoid redundant charges. This is the true "injected every turn" mechanism.
  - Use cases: product-level role definitions, multi-tenant permission isolation, fixed output format constraints.

  **3. Rules (path-scoped, `.claude/rules/`)**
  - Loading mechanism: re-injected as `<system-reminder>` **each time a matching-path file is accessed**. Per-tool-call cost, higher than CLAUDE.md, but supports fine-grained scope control.

* **Writing Iron Laws (apply to all carriers)**:
  1. **Minimalism**: Each instruction must be no more than 2 lines. Use lists, not paragraphs.
  2. **Zero ambiguity**: Forbidden to use vague adverbs like "try to," "if possible," "in general." Must use deterministic verbs: "forbidden," "must," "force."
  3. **No redundancy**: Strip all background introductions and explanatory text. Keep only the behavioral instruction itself. The AI does not need to understand "why" — only "what to do."
  4. **Explicit conflict resolution**: If instructions potentially contradict, explicitly declare priority within the file (e.g., "later instructions override earlier ones"). Never rely on AI discretion.

* **Rationale**: Auto-generated instructions are generic filler. Ambiguous instructions force the AI to probabilistically guess intent. The essence of persistent instructions is **compressing your decision boundary** — the more precise the instructions, the more deterministic the AI's behavior, and the lower the hallucination probability.

**#7: Obey DRY — Build a Skill the Moment a Workflow Repeats 3 Times**

* **Breakdown**: Any manually typed repetitive prompt or debugging workflow, once executed 3 times, must be immediately packaged as a `.claude/skills/SKILL.md`.
* **Rationale**: Convert implicit personal operational knowledge into explicit, machine-callable programmatic assets, reducing human input variance and token consumption.

**#8: Iteration over Perfection — Use `/loop` for Closed-Loop Error Correction**

* **Breakdown**: Abandon the expectation that AI will generate flawless code in one shot. After producing the initial version, immediately feed it to the compiler or test script, using error messages to drive correction.
* **Rationale**: Large language models have an overwhelming advantage in "locally repairing code based on deterministic error logs," far exceeding their ability to "zero-shot generate complex, error-free logic."

**#9: Introduce a Third-Party Judge — One Model Builds, Another Model Reviews**

* **Breakdown**: Adopt a cross-model review mechanism. If Claude generates the code, it must be reviewed by GPT-4o or Gemini.
* **Rationale**: A single model, constrained by its own algorithmic preferences and training data, has significant logical blind spots and cannot deeply audit its own output. Cross-model adversarial review dramatically increases the detection rate of deep logical vulnerabilities.

**#10: Practice Spec Coding, Reject Vibe Coding — Establish Rigorous Specifications**

* **Breakdown**: The requirements document (Spec) given to AI must have compiler-level determinism. Using fragile line numbers as reference points in specs is strictly forbidden. A qualified spec must contain exactly: precise input data structures, expected output formats, all exception handling branches, and clear performance or boundary constraints.
* **Rationale**: Vague, casual, intent-unclear prompts (Vibe Coding) force the AI to probabilistically guess intent — this is the direct root cause of code hallucinations. A rigorous spec locks down the AI's generation boundary, ensuring absolute determinism in the output.

---
---

<a name="-中文"></a>
# AI 辅助编程十戒 🇨🇳

**第一戒：计划必须高度抽象——严禁包含实现细节**

* **细则**：规划阶段只确立系统架构、数据流和核心步骤。AI 必须提供更高维度的抽象描述，刻意保持模糊。严禁在计划中出现具体代码片段或底层 API 调用。
* **原理**：过早引入细节会产生方向性偏差，导致小错误在后续步骤中不断放大。只要宏观模糊计划在逻辑上正确，即使 AI 在代码生成时出错，也能重新读取高层计划、检测逻辑冲突并自我纠正。

**第二戒：将任务分解为物理和逻辑上解耦的子任务——按依赖拓扑顺序执行**

* **细则**：强制将大型需求拆分为相互独立的模块，用并行或批量指令处理这些子任务。
* **执行顺序铁律（前置优先）**：
  1. **先运行最快、最基础的验证**：数据是否存在且可读？网络是否连通？API 是否返回预期格式？所有环境依赖是否就绪？用最少代码（哪怕一条 curl）在秒级内确认。
  2. **再运行依赖前置结果的主逻辑**：所有前置验证通过后，才开始编写和执行主代码。
  3. **独立子任务必须并行运行**：标注每个步骤的输入依赖；若两个步骤无数据流依赖，强制并行执行。
  4. **执行顺序不确定时，询问用户**：AI 严禁自行假设执行顺序，必须明确展示依赖图并请用户确认。
* **反模式**：在线下载数据集的同时启动评估——评估代码依赖数据集，造成耦合。正确做法：先独立下载数据集并验证完整性，再启动评估；下载和 API 连通性测试可并行进行。
* **原理**：AI 处理强耦合任务时极易产生"改 A 坏 B"的幻觉。解耦是安全并行的唯一物理前提，能大幅降低上下文干扰、提升执行速度。先验证前置条件可在秒级暴露致命问题（数据缺失、网络中断），避免主逻辑运行数小时后崩溃。

**第三戒：每次任务完成后强制执行 `/simplify`**

* **细则**：任何功能验证通过后，立即调用 `/simplify` 或等效的清理命令。
* **原理**：AI 生成的代码天然携带冗余防御、未使用变量和过度注释。此步骤强制执行 AST 级（抽象语法树）重构，剔除死代码，维持代码库的高信息密度和极简主义。

**第四戒：维护高层级的 AI 实验与错误日志（保障长期可维护性）**

* **细则**：强制 AI 在开发过程中记录其试错经验。三类日志必须存在：

1. **方法论成功日志**：对每个优化目标，明确记录"哪个操作改善了结果"，并要求 AI 简析背后的算法或逻辑原因。所有成功节点必须不遗漏地记录。
2. **方法论失败日志**：记录导致退化或彻底失败的尝试路径，以及算法或设计层面的失败分析。
3. **工程错误日志**：单独记录纯执行层面的错误——错误的依赖导入、假设不存在的文件路径、环境配置遗漏、纯代码逻辑拼写错误。
* **原理**：让 AI 的试错边界显式化。用历史实验数据收敛搜索空间，防止 AI 在长期项目中反复落入同一陷阱。

**第五戒：用结构化文档进行状态交接——用概念描述定位代码**

* **细则**：整合 Anthropic 的工作流逻辑。

1. 代码注释绝不包含"开发进度"（如"修复了 bug X"）。注释只解释业务逻辑。
2. 永远不用"行号 + 文件路径"定位目标。改用语义化、概念性描述（如"修改负责用户认证的核心中间件"）。
3. 使用独立、标准化的文本制品（如 `PROGRESS.md` 或状态文件）交接上下文、记录开发进度，与对话历史解耦。
* **原理**：行号是极其脆弱的动态坐标，极易失效。基于概念的描述赋予指令更强的健壮性。将状态管理从代码注释和聊天记录中分离到独立文档，是对抗 LLM "上下文失忆"最有效的机制。

**第六戒：永远不用 `/init`——手写所有持久化指令（`CLAUDE.md` 与系统消息）**

* **细则**：持久化指令有两种载体，机制和用途各不相同，需理解各自特性：

  **1. CLAUDE.md（文件型，项目/全局级）**
  - 物理形态：放置在项目根目录 `CLAUDE.md` 或全局 `~/.claude/CLAUDE.md`。
  - 加载机制：在会话开始时读取一次并记忆（缓存到内存）。后续每次 API 调用都携带此缓存内容——不会每轮重新读取文件。会话中途修改文件**不会**热重载；需要新会话才能生效。
  - 适用场景：项目级技术栈约束、命名规范、禁止行为、长期工程规则。

  **2. 系统消息（API/平台型）**
  - 物理形态：通过 API 调用中的 `system` 字段显式传递，或在 Claude.ai 平台的项目"系统提示"配置中设置。
  - 加载机制：**每次 API 请求都显式携带**，使用 Anthropic 提示词缓存避免重复计费。这才是真正的"每轮注入"机制。
  - 适用场景：产品级角色定义、多租户权限隔离、固定输出格式约束。

  **3. Rules（路径范围型，`.claude/rules/`）**
  - 加载机制：**每次访问匹配路径的文件时**，以 `<system-reminder>` 形式重新注入。每次工具调用都有成本，高于 CLAUDE.md，但支持细粒度范围控制。

* **写作铁律（适用于所有载体）**：
  1. **极简主义**：每条指令不超过 2 行。用列表，不用段落。
  2. **零歧义**：严禁使用"尽量"、"如果可能"、"一般来说"等模糊副词。必须使用确定性动词："禁止"、"必须"、"强制"。
  3. **无冗余**：剔除所有背景介绍和解释性文字。只保留行为指令本身。AI 不需要理解"为什么"——只需知道"做什么"。
  4. **显式冲突解决**：若指令可能相互矛盾，在文件内显式声明优先级（如"后面的指令覆盖前面的"）。绝不依赖 AI 自行裁量。

* **原理**：自动生成的指令是泛化填充物。模糊指令迫使 AI 概率性地猜测意图。持久化指令的本质是**压缩你的决策边界**——指令越精确，AI 的行为越确定，幻觉概率越低。

**第七戒：遵守 DRY——工作流重复 3 次立即封装为 Skill**

* **细则**：任何手动输入的重复提示或调试工作流，一旦执行 3 次，必须立即打包为 `.claude/skills/SKILL.md`。
* **原理**：将隐性的个人操作知识转化为显式的、机器可调用的程序化资产，降低人工输入差异和 token 消耗。

**第八戒：迭代优于完美——用 `/loop` 实现闭环纠错**

* **细则**：放弃期待 AI 一次生成完美代码的幻想。生成初版后，立即将其提交给编译器或测试脚本，用错误信息驱动修正。
* **原理**：大型语言模型在"基于确定性错误日志局部修复代码"上具有压倒性优势，远超其"零样本生成复杂无错逻辑"的能力。

**第九戒：引入第三方裁判——一个模型构建，另一个模型审查**

* **细则**：采用跨模型审查机制。若 Claude 生成代码，必须由 GPT-4o 或 Gemini 进行审查。
* **原理**：单一模型受其算法偏好和训练数据的约束，存在显著的逻辑盲区，无法深度审计自身输出。跨模型对抗性审查能大幅提升深层逻辑漏洞的检出率。

**第十戒：践行 Spec Coding，拒绝 Vibe Coding——建立严格规范**

* **细则**：提交给 AI 的需求文档（Spec）必须具有编译器级别的确定性。严禁在 Spec 中使用脆弱的行号作为参考点。合格的 Spec 必须且只包含：精确的输入数据结构、预期输出格式、所有异常处理分支、以及明确的性能或边界约束。
* **原理**：模糊、随意、意图不清的提示（Vibe Coding）迫使 AI 概率性地猜测意图——这是代码幻觉的直接根源。严格的 Spec 锁定了 AI 的生成边界，确保输出的绝对确定性。

---
