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

**Before writing anything**, read both reference files:
- `references/format-rules.md` — 5 format rules that prevent rendering bugs. Must be followed for every function.
- `references/step3-generate.md` — Part 1–4 document templates to copy and fill in.

Write all four parts in order. Write each function's docs immediately after reading its source — never buffer to the end.

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
