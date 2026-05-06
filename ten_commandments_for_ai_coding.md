[🇨🇳 中文版](ten_commandments_for_ai_coding.zh.md)

# Ten Commandments for AI-Assisted Coding

**#0 (Highest Priority): Every Task or Symptom Must Pass Through the "Measure → Hypothesize → Eliminate" Intermediate Layer — Never Act Directly**

* **Breakdown**:
  1. **Measure first, act later**: When facing any problem, goal, or unexpected result, the first step is to identify and list all observable metrics, obtain actual data using tools, and write results to a file (e.g., `metrics2monitor.md`). Jumping straight to modifying code or configuration without measuring is strictly forbidden.
  2. **Generate a hypothesis space from measurements — always multiple**: Every measurement result must map to multiple possible causes, written as a hypothesis list. Jumping directly from an observation to a single conclusion is strictly forbidden.
  3. **Independently verify and structurally record each hypothesis**: Check each one separately, recording "evidence + conclusion (confirmed/eliminated)" per item. Write to `monitor_spec.md` or equivalent — every check item must appear independently. Holistic conclusions ("looks fine overall," "seems normal") are strictly forbidden.
  4. **Only then act**: Execute targeted action after root cause is identified through systematic elimination.

* **Rationale**: AI only has text pattern-matching capability. Training data is dominated by patterns like "slow code → look at code → fix code." The intermediate expert layer — "first measure system metrics → branch into multiple hypotheses → systematically eliminate" — is implicit domain knowledge that experienced engineers execute automatically but never write down. AI cannot fit this layer from training data. Without forcing it, AI goes straight to the most obvious surface action, making blind modifications without knowing the actual root cause, then claiming "solved." The deeper purpose of forced structured output (every check item must appear as an independent entry with evidence and conclusion written to a file): AI cannot claim "passed" for an item it has not yet written, eliminating "feels-like-it-works" lazy compliance.

* **Positive example (GPU training running slowly)**:
  1. Measure first: run `nvidia-smi` → record each GPU's utilization and memory; write to `metrics2monitor.md`
  2. Utilization: 30% (low) → immediately branch into hypotheses: A) DataLoader single-process bottleneck? B) Parallelism underused in torchrun? C) Multi-GPU communication overhead? D) CPU-bound?
  3. Check each → inspect `num_workers` (=0) → check `htop` (CPU saturated) → root cause confirmed: DataLoader single-process
  4. Write pass/fail + reason for each hypothesis → write to `monitor_spec.md`
  5. Fix: `num_workers=8`, rerun → utilization rises to 85% → record verification result

* **Negative example (AI as headless fly)**:
  1. Code runs slowly → directly open training script
  2. Scan code: "this for loop might be inefficient" → vectorize it
  3. Report: "Code optimized, should be faster now"
  4. Reality: bottleneck was DataLoader; code change was meaningless; utilization still 30%; root cause never found

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

*Adapted from the methodology of [Humanize](https://github.com/humania-org/humanize) by Dr. Sihao Liu, with personal modifications and additions.*
