---
name: gen-draft
description: "Generate a high-level draft document (draft.md) from a user's task description. Use ONLY when the user explicitly invokes /gen-draft or says '写draft', '生成draft'. Never trigger automatically. The draft captures WHAT and WHY, never HOW."
---

# Gen Draft

Generate a `draft.md` that captures a task at the right abstraction level — high enough to avoid premature implementation decisions, concrete enough to be unambiguous.

The draft is the first step in a chain: **draft → plan → implementation**. Its job is to lock down the problem definition so that a separate AI (or human) can later generate a correct plan without needing to re-interview the user.

## When to Use

Only when the user explicitly asks: `/gen-draft`, `写draft`, `生成draft`.

## Step 1 — Gather Context

Before writing anything, understand the task. Ask the user if anything is unclear. You need:

- What is the goal? (one sentence)
- What are the inputs? (data sources, formats, APIs — described abstractly)
- What are the expected outputs? (deliverables, not file names)
- What constraints exist? (performance, compatibility, fairness, cost)
- What is already known? (prior experiments, verified facts, failed approaches)
- What decisions need the user to weigh in? (trade-offs with no obvious answer)

If the conversation already contains this information, extract it — don't re-ask what you already know.

## Step 2 — Write draft.md

Output to `draft.md` in the project root. Use this structure:

```markdown
# {Task Title} — Draft

## Goal
{One paragraph: what this task achieves and why it matters.}

## Constraints
{Numbered list of non-negotiable rules for this task.}

## Inputs
{What goes in: data sources, APIs, formats. Described by role, not by path or schema.}

## Outputs
{What comes out: deliverables described by content, not by file name or column list.}

## Environment & Resources
{All confirmed external info the implementer needs: API endpoints, keys, cluster details, existing tools/envs, submission methods. These are facts, not decisions.}

## Known Facts
{Verified conclusions from prior work or testing. Only results, not the process that produced them. Use tables for structured comparisons.}

## Execution Order
{Numbered high-level steps. Each step is one sentence describing WHAT to do, not HOW.}

## Decision Points
{Table: questions that need user input, with options and trade-offs.}
```

Sections can be omitted if genuinely not applicable (e.g., no decisions needed). Don't add sections not listed here.

## The Critical Distinction: Facts vs Implementation

A draft must contain all **known facts** the implementer needs, but zero **implementation decisions**. Confusing these two is the most common mistake.

### Known Facts — MUST include

These are confirmed, externally-given pieces of information. Without them, whoever reads the draft cannot do the job. Always include:

- **API endpoints and credentials**: URLs, keys, auth methods — these are given inputs, not design choices
- **Environment info**: what Python version is available, what cluster scheduler to use, what venv already exists
- **Verified test results**: "Model X returns content=null when thinking is on" is a fact, not an implementation detail
- **Resource locations**: dataset names, existing tool paths, submission commands
- **Prior failures**: "We tried X and it didn't work because Y"

Example (good — this is a fact):
```
Provider A endpoint: https://api.provider-a.com/v1/chat/completions
Provider A key: <key from user>
```

### Implementation Details — MUST NOT include

These are decisions about *how to build* the solution. They belong in the plan or code, not the draft:

- Config file templates, YAML/JSON structures
- Code snippets, class names, function signatures
- Which library or framework to use
- How to refactor existing code ("modify file A, add function B")
- Internal architecture decisions ("use a thread pool with N workers")

Example (bad — this is an implementation decision):
```yaml
params:
  temperature: 0
  max_tokens: 5
  workers: 16
```

### The Test

For every piece of information in the draft, ask: **"Did the user or the environment give us this, or did we decide it?"**
- Given → keep it (it's a fact)
- Decided → remove it (it's implementation)

## Step 3 — Self-Check

After writing the draft, verify these three things. Fix violations before showing to the user.

### Check 1: No Implementation Decisions

Scan for and remove:
- Code snippets, config templates
- Architecture or design choices
- Library/framework selections
- Code change lists ("modify module X, add class Y")

### Check 2: All Known Facts Present

Scan the conversation for information the user provided. Make sure none of these are missing from the draft:
- API endpoints, keys, credentials
- Environment details (paths, tools, cluster info)
- Verified test results and their conclusions
- Resource locations and access methods

If the user gave you a curl command, the endpoint and auth info from it belong in the draft. The curl syntax itself does not.

### Check 3: Clear Input/Output Spec

Every draft must answer: what goes in, what comes out. Describe by **content and purpose**, not by schema.

- Bad: "output `detail.csv` with columns: question_id, gold_answer, pred_answer"
- Good: "per-item results showing model answer, correct answer, and match status"

## Example

**User says**: "I want to benchmark a few free models on multilingual MMLU"

**Good draft excerpt**:
```
## Goal
Compare multiple free models on multilingual MMLU accuracy across two low-resource languages.

## Constraints
1. All models use identical prompt and parameters for fair comparison
2. Results must be written to disk incrementally, supporting crash recovery

## Environment & Resources
- Provider A: <endpoint URL>, Key: <key from user>
- Provider B: <endpoint URL>, Key: <key from user>
- Python env: <path provided by user> (has datasets package)
- Submission: ssh to scheduler node, then sbatch

## Known Facts
| Model | Connectivity | Thinking | Verdict |
|-------|-------------|----------|---------|
| Model X | OK | None | Can run |
| Model Y | OK | Forced, content=null | Skip |
```

**Bad draft excerpt** (implementation decisions mixed in):
```
## Config
- temperature=0, max_tokens=5, workers=16    <- these are implementation decisions, not facts

## Code changes
- modify config loader to support multi-provider  <- this is implementation planning
- add new endpoint class for Provider B            <- same
```
