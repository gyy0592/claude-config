# Gen Draft — Phase 2: Write draft.md

You have the user's answers. Now write the draft.

Output to `draft.md` in the project root. If the user asked to append (not overwrite), append a new section.

---

## Draft structure

```markdown
# {Task Title} — Draft

## Goal
{One paragraph: what this task achieves and why it matters.}

## Constraints
{Numbered list of non-negotiable rules.

**Mandatory skill reads** (if any):
  "Before [trigger], must read [skill path]: [reason]"

**Destructive operation guards** (if any):
  "[operation] requires explicit user approval before executing: [reason]"
}

## Inputs
{What goes in: data sources, APIs, formats. Described by role, not by path or schema.}

## Outputs
{What comes out: deliverables described by content, not by file name or column list.}

## Environment & Resources
{Confirmed external facts the implementer needs: endpoints, keys, cluster info, existing tools/envs.}

## Known Facts
{Verified conclusions from prior work. Only results, not process. Use tables for comparisons.}

## Execution Order
{See format rules below.}

## Observable Outputs
{See requirements below.}

## Decision Points
{Table: open questions needing user input, with options and trade-offs.}
```

Omit sections that are genuinely not applicable. Do not add sections not listed here.

---

## Execution Order format (HARD RULES)

Every step must have exactly one tag: `[independent]` or `[depends: N, M]`. No exceptions.

Group consecutive `[independent]` steps under `── parallel ──` markers:

```
── parallel ──
1. [independent] Verify dataset exists
2. [independent] Test API connectivity
── end parallel ──
3. [depends: 1, 2] Run evaluation
4. [depends: 3] Generate report
```

**Prerequisite-first**: the first group must be validation/setup. Main logic never appears before all prerequisites pass.

---

## Observable Outputs requirements

List concrete items for each category, or flag `⚠ not specified — confirm with user`:

- Scalar metrics tracked over time
- Per-item details recorded
- Intermediate variables to monitor
- Artifacts to save

Never assume defaults. If the user said nothing about a category, flag it.

---

## The critical distinction: facts vs implementation

**Include** (known facts — given by user or environment):
- API endpoints, credentials, auth methods
- Environment details: Python path, cluster scheduler, existing venvs
- Verified test results and their conclusions
- Resource locations, submission commands
- Prior failures and why they failed

**Exclude** (implementation decisions — belong in plan/code, not draft):
- Config file templates, YAML/JSON structures
- Code snippets, class names, function signatures
- Which library/framework to use
- How to refactor existing code
- Internal architecture decisions

**The test**: "Did the user or the environment give us this, or did we decide it?"
- Given → keep
- Decided → remove

---

## Self-check before showing to user

Run all five checks. Fix violations before presenting.

1. **No implementation decisions** — scan for code snippets, config templates, architecture choices. Remove them.
2. **All known facts present** — scan conversation for user-provided info (endpoints, keys, paths, test results). None missing.
3. **Clear input/output spec** — described by content and purpose, not by schema or column list.
4. **Execution Order is prerequisite-first** — HARD FAIL if: any step missing its tag, main logic before validation, `[independent]` steps not in parallel group, undeclared dependencies.
5. **Observable Outputs are explicit** — not empty, not vague. Unfilled items marked `⚠ not specified`.
