---
name: code-tree
description: "Generate a structured, navigable code documentation document for a Python codebase — the 'code tree'. Use this skill whenever the user asks to document a codebase, explain how the code works end-to-end, generate a code tree, write code documentation, understand call chains, or map out how functions relate to each other. Trigger on: '生成代码树', '代码树', '给我写代码文档', '解释代码结构', '画一个调用树', 'generate a code tree', 'document the codebase', 'write code docs', 'explain how the code works', 'map out the call chains', 'code documentation'. The output is a single Markdown file with: (1) directory tree, (2) ASCII call trees per functional area, (3) per-function docs with always-visible input/output descriptions and collapsed technical details. After generating, the skill runs ask-claude to verify format quality and fixes issues."
---

# code-tree — Structured Codebase Documentation Generator

## Step 0: Ask output language first (before reading any code)

Before doing anything else, ask the user:

> "What language should the document be written in? (e.g. Chinese, English, Japanese, etc.)"

Use that language for **all** prose text in the output document — summaries, motivation, input/output descriptions, call chain labels. Code snippets and file paths stay in their original form.

---

## Step 1: Understand the scope

Ask the user (or infer from context):
- Which directory is the repository root?
- Are there specific stages/modules to focus on, or document everything?
- Output file path (default: `<repo_root>/report/code-tree.md`)

If the user already provided all this, skip straight to Step 2.

---

## Step 2: Map the codebase

Read the directory structure and identify the major functional areas. A "functional area" is a group of files that together implement one stage or pipeline step (e.g., "Stage 1: Data Collection", "Stage 3: Injection").

For each Python file in scope:
- Read its top-level docstring and imports to understand its role
- List all public functions/classes and their approximate line numbers
- Note which functions call which other functions (build a mental call graph)

Write incrementally to the output file as you go — do not wait until the end.

---

## Step 3: Generate the document

The output document has four parts:

### Part 1 — Title and project overview

```markdown
# Code Tree — <Project Name>

## Overview

<2-4 sentence description of what the project does and why>

**Key components**: <model names, dataset names, architecture details if relevant>

**N experimental stages**:
1. **Stage 1**: <one-sentence description>
...
```

### Part 2 — Directory structure

Use a fenced code block with the full directory tree. Annotate each important file with a `# comment` explaining its role:

```
project/
├── code/
│   ├── stage1/
│   │   ├── launcher.py       # Multi-GPU launcher
│   │   └── run_batch.py      # Per-GPU worker (main logic)
...
```

### Part 3 — Functional areas with call trees and function docs

For each functional area, follow this exact structure:

````markdown
### 功能N: <Area Name>

#### 调用树

```
entry_file.py: main()                     ← CLI entry point
└── _main_body(args, config_path, dir)
    ├── helper_a(x, y)                    ← helper_file.py
    │   └── sub_helper()                  → output/path/*.npz
    └── subprocess → worker.py: main()   ← each GPU spawns one
        ├── function_b()                  ← hooks.py
        └── function_c()                  → records/tokens/*.npz
```

---

#### Entry: `code/stage1/launcher.py`

---

<a id="function_name"></a>

#### `function_name(arg1, arg2)` — `code/stage1/file.py:42`

**Summary**: One sentence describing what it does.

**Motivation**: Why this function exists — what problem it solves or what design choice it encodes.

**Input**: Plain human sentence — what it accepts, where the data comes from, and what role it plays. Never a variable list here. Always visible.

**Output**: Plain human sentence — what it returns or writes, and how callers use it. Always visible.

<details>
<summary>🔍 Technical details (parameters · code)</summary>

**Parameters**:
- `arg1`: type, description
- `arg2`: type, description

**Returns**: type, description

```python
# Line 47-48: key implementation detail
some_code = here
```

</details>

**Call chain**:
- Called by [`caller_function()`](#caller_name) (`file.py:133`)
- Calls → [`callee_function()`](#callee_name) (`other_file.py:27`)

---
````

Repeat for every function in this functional area, then move to the next `### 功能N`.

### Part 4 — Cross-module data flow diagram

A plain-text diagram (using `─`, `►`, `│`, `┌`, `└`, `┐`, `┘`) showing how data flows between stages:

```
Stage 1 → records/*.npz → Stage 2 → bias_vectors.npz → Stage 3 → ...
```

---

## Format rules (read these before writing a single line)

These rules exist because the previous version of this document had real rendering bugs caused by violating them.

### Rule 1: Never nest `<details>` blocks

Each function gets exactly **one** `<details>` block — the `🔍 Technical details` block. It opens after the Output line and closes before the Call chain section. There is no second `<details>` inside it.

Why this matters: nested `<details>` breaks GitHub Markdown rendering silently — the outer block appears to close, but the document structure is corrupt.

Self-check: after writing each function, count `<details>` openings and `</details>` closings for that function — they must be equal, and both must equal 1.

### Rule 2: Input/Output are always-visible human sentences

**Input** and **Output** lines sit outside any `<details>` block. A reader browsing the document should understand what every function does without expanding anything.

❌ Wrong (put inside details, or is a variable list):
```
**Input**: `hf_home`: str, HuggingFace cache root
```

✅ Right (outside details, plain prose):
```
**Input**: Accepts the HuggingFace local cache root and a model ID, used to locate the weight shard directory of the downloaded model.
```

Variable names and types belong in the `🔍 Technical details` block, not in the visible Input/Output.

### Rule 3: Every `### 功能N` must have a `#### 调用树` first

The ASCII call tree comes immediately after the `### 功能N` heading, before any function docs. It shows the full entry→leaf call hierarchy for that functional area.

ASCII call tree characters: `└──` `├──` `│` for structure; `←` for "this is in file X"; `→` for "writes to path Y".

### Rule 4: Every function needs an HTML anchor

The anchor `<a id="function_name"></a>` goes on the line immediately before the `####` heading. The anchor name is the snake_case function name. The Call chain section references it as `[function_name()](#function_name)`.

### Rule 5: Write incrementally

Write each function's documentation to the output file immediately after reading that function's source code. Do not buffer everything in memory and write at the end — this risks losing work and makes progress invisible.

---

## Step 4: Quality check with ask-claude (mandatory)

After the document is written, run up to **2 rounds** of automated quality checking.

**Invocation** — use Bash to call the shell script directly. Do NOT use the `humanize:ask-*` Skill tool (it returns driver documentation only, not a real model response — verified 2026-04-27):

```bash
bash /home/Barry/Programs/humanize/scripts/ask-claude.sh "Review this code documentation file and check for these specific issues:

1. NESTED DETAILS: Are there any <details> blocks nested inside another <details> block? List any such locations by function name.
2. INPUT/OUTPUT FORMAT: Are any **Input** or **Output** lines written as variable lists (like '- \`param\`: type, description') instead of plain prose sentences? List violations.
3. MISSING CALL TREES: Does every '### 功能N' section have a '#### 调用树' subsection immediately after it? List any sections that are missing the call tree.
4. MISSING ANCHORS: Are there function headings (#### \`function_name\`) that lack a matching '<a id=\"...\"></a>' anchor immediately before them? List any missing.

File to review: <output_file_path>

For each issue found, give: issue type, location (function name or section heading), and a brief description. If no issues found in a category, say 'OK'. End with a summary: PASS if all categories are OK, FAIL if any issues found."
```

**After receiving feedback**:
- If feedback says PASS → done, report success to user.
- If feedback says FAIL with specific actionable issues → fix them directly in the output file, then run a second round.
- If feedback is unclear or contradictory → ask the user to clarify before making changes.
- After 2 rounds, stop regardless of outcome and report any remaining issues to the user.

---

## What good output looks like

The gold-standard reference is:
`/home/Barry/github_repo/LLM_sampling_implement/report/code-tree_v2.md`

Read the first 200 lines of that file if you want to see the exact formatting in action. The "Bitter Lesson" section at the top of that file also documents the format rules from the perspective of past mistakes.

---

## When to ask the user

Ask the user when:
- You cannot determine the functional area boundaries (how to group files into `### 功能N` sections)
- A function is too complex to summarize in one sentence without guessing at intent
- The `ask-claude` feedback is unclear or contradicts itself

For everything else (file reading, incremental writing, format corrections after ask-claude feedback), proceed autonomously.
