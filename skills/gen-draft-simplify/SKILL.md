---
name: gen-draft-simplify
description: "Generate a project-specific draft_simplify.md for a code repository — a high-level plan for an upcoming maintainability refactor that preserves runtime behavior bit-for-bit. Use this skill whenever the user wants to PLAN a code-cleanup / refactor / maintainability pass on a whole repository, before any code is changed. Trigger aggressively on phrases like '生成simplify draft', '写一下化简方案', '重构方案', '生成可维护性化简的draft', '帮我规划一下重构', 'plan a refactor', 'draft a simplify plan', 'generate a refactor plan for this repo'. The skill does NOT execute the refactor — it only produces the planning document. The output is a single instantiated draft_simplify.md at the repo root, with all placeholders filled from a mandatory AskUserQuestion intake. Do NOT trigger for: single-PR review (use /simplify), one-shot small edits, or when the user explicitly asks to start refactoring immediately. Do NOT confuse with /gen-draft (which is the generic draft generator) — this skill is specialized: the output draft already contains the full simplify protocol (24 hard rules across 6 categories, behavior-preservation contract, dual-gate per-modification, anti-oscillation, parallel-subagent loop spec)."
---

# gen-draft-simplify — Generate a project-specific simplify-refactor draft

> **Before any `AskUserQuestion` call, load and apply `~/.claude/rules/6_user_facing_questions.md`** (mandatory plain-language guard — four-piece set + jargon self-scan).

## What this skill does and does not do

**Does**:
- Run a single `AskUserQuestion` to collect the project's specifics (repo path, entry script, baseline command, protected blocks, etc.)
- Read the canonical template at `references/draft_template.md`
- Substitute every `{{...}}` placeholder with the user's answers
- Write the instantiated draft to `<REPO_PATH>/draft_simplify.md`
- Stop

**Does not**:
- Execute the refactor
- Modify any source code
- Run any tests, baselines, or scans
- Dispatch subagents for the refactor loop

The draft this skill produces is the **input** to a future execution skill or RLCR-style loop. Generation and execution are intentionally separated so that the draft can be reviewed, version-controlled, and iterated on before any code is touched.

The why: a refactor plan is the highest-leverage document in a maintainability pass — it defines the safety contract (what counts as preserving behavior), the optimization scope (what kinds of changes are allowed), and the validation gates (what must pass before any write). Producing the plan is a discrete, reviewable step. Mixing it with execution makes both worse.

## Workflow

### Step 1 — Intake (mandatory, never skip)

Read `references/intake.md` for the full question template and the validation steps that follow the user's reply.

Send a single `AskUserQuestion` covering all required fields at once. Do not split into multiple turns. Do not assume defaults silently. Any field the user leaves blank → mark `⚠ not specified` in the output draft and ask once more before writing the file.

The why for batching: each round-trip costs the user attention. Asking everything at once also forces clarity on which parameters matter and surfaces missing ones immediately.

### Step 2 — Instantiate the draft

1. Read `references/draft_template.md` end to end
2. **Probe `ASK_TOOL_SCRIPT_DIR`** if the user did not explicitly provide it: try `~/Programs/humanize/scripts/` first, then `~/.claude/plugins/cache/PolyArch/humanize/<latest>/scripts/`. Verify `ask-claude.sh` (and any other selected tools) actually exist there. If neither directory has the required scripts, mark `⚠ not found` and pause — do not fabricate a path. The why: this is the single most failure-prone field. The 2026-04-27 minimal-unit eval verified that `humanize:ask-*` invoked through the Skill tool returns driver text inline rather than executing the model; subagents in Stage 2 will get stuck if the draft does not tell them to Bash-call the script directly. A wrong or missing path here is a permanent error baked into the plan.
3. Replace every `{{...}}` placeholder with the corresponding intake answer (or detected value)
4. Drop the "占位符清单" header block at the top of the template (it is meta-documentation for the template, not for the instantiated draft) — but keep all numbered sections
5. Write the result to `<REPO_PATH>/draft_simplify.md`
6. If `<REPO_PATH>/draft_simplify.md` already exists, do NOT overwrite — confirm with the user first whether to overwrite, append a versioned section, or abort

### Step 3 — Self-check before showing the user

Before declaring done, scan the written file:

- All `{{...}}` placeholders are gone (replaced or marked `⚠ not specified`)
- The 24 hard rules in the Constraints section are present and unchanged from the template
- Execution Order steps each carry an `[independent]` or `[depends: N]` tag and parallel groups are wrapped in `── parallel ──` / `── end parallel ──`
- No code snippets / yaml templates / class names sneaked into the draft
- Observable Outputs has no empty bullets

If any check fails, fix it before reporting completion.

### Step 4 — Report

Tell the user where the draft was written and what is in it (one short paragraph). If any field was marked `⚠ not specified`, list those explicitly so the user can fill them in before the execution skill picks the draft up.

## Triggering boundary

If the user says "化简代码" / "refactor this repo" with intent to **execute immediately**, this is the wrong skill. Hand off to whatever execution skill exists, or prompt the user to first generate the draft (this skill) and then execute.

If the user invokes `/gen-draft` for a non-refactor task, that is the generic gen-draft skill — not this one. This skill is only for the specific case of "I want a simplify-refactor plan for a code repo".

## Anti-patterns to refuse

- ❌ Skipping the intake because "the conversation already mentioned the repo path" — always confirm via `AskUserQuestion`; previous-turn context drifts and the intake is the single source of truth for the draft
- ❌ Filling placeholders with guesses or sensible defaults silently
- ❌ Adding rules to the draft that are not in the template (the template's 24 rules are calibrated; ad-hoc additions create drift across projects)
- ❌ Removing rules from the draft because "they don't apply to this project" — if a rule truly doesn't apply, the user should say so explicitly, then mark it as inapplicable in the draft rather than deleting it
- ❌ Starting any actual refactor work after writing the draft. Stop at Step 4.

## Files in this skill

- `SKILL.md` — this file
- `references/intake.md` — full AskUserQuestion question schema
- `references/draft_template.md` — the canonical template with `{{...}}` placeholders
- `evals/evals.json` — test prompts for skill iteration
