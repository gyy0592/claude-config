---
name: paper-overview
description: Produces a reader-friendly overview of an academic paper in a fixed eight-section structure with intuitive analogies, structured Before/After comparisons, key formulas with where-blocks, and experiment tables. Use when the user says "overview this paper", "quick analysis", "概览", "快速分析", "分析这篇论文", or invokes /paper-overview. Also invoked as the first phase of paper-reader before the chunk-by-chunk deep read.
---

# paper-overview

## Why this skill exists

A reader picking up a new paper needs two things at different times:

1. **First pass (5-10 minutes):** a global map — what problem, why it matters, what changed, key numbers. This is what paper-overview produces.
2. **Deep pass (30-60 minutes):** formula-level precision with self-checks. This is what paper-reader's chunk-by-chunk protocol produces.

Existing sub-agents can produce decent overviews, but their quality is unstable: formulas sometimes have errors, design details get silently dropped, there is no structured Before/After comparison, and no formula-to-paper cross-referencing. This skill stabilizes the output by enforcing a fixed structure, lightweight self-checks, and mandatory comparison blocks — without the full recursive self-check loop that makes paper-reader slow.

## Output language

Follow the user's language. If the user writes the request in Chinese, output in Chinese. If English, output in English. If explicitly specified, follow that. The SKILL.md itself is in English; the output is not.

## Trigger

- Standalone: `/paper-overview`, `/overview`, "overview this paper", "quick analysis", "概览", "快速分析", "分析这篇论文", or similar.
- From paper-reader: automatically invoked as Phase 0 before the chunk-by-chunk deep read.

## Output file

- `<paper_name>-overview.md` in the current working directory.
- When invoked from paper-reader, this file is written first, then paper-reader proceeds to write `<paper_name>-output.md` as usual.

## The eight sections (fixed structure, in order)

Every overview contains exactly these eight sections. Do not reorder, merge, or skip any section.

### Section 1: One-line summary + Research motivation

- One sentence summarizing what the paper does and what result it achieves.
- One paragraph on the research motivation: what real-world or scientific need drives this work, what gap exists.

### Section 2: Core problem — why existing methods fall short

- **Mandatory comparison table**: a markdown table with columns `Method category | Representative work | Limitation`. At least 3 rows covering the main prior approaches the paper positions against.
- One paragraph synthesizing the table into the paper's core research question.

### Section 3: Key concepts

For each core concept introduced by the paper (typically 2-4 concepts):

- **Intuitive analogy or scenario** (everyday example, physical system, toy problem) — the reader should be able to re-derive the rough shape of the idea on a napkin after reading this.
- **One-paragraph mathematical definition** with a self-contained `where ... is ...` block. Not a full derivation — just the definition and what each symbol means.
- **Why it exists**: one sentence connecting the concept back to the problem in Section 2.

### Section 4: Method walkthrough

Walk through the method in the paper's own section order. For each subsection:

- **What problem does this component solve?** (one sentence)
- **How does it work?** (one paragraph, with formula if central)
- **Before/After/Diff/Insight block** (mandatory when the component replaces or modifies a prior method):

```
**Before (<prior method label>):**
<equation or description>
where <symbol> is ...

**After (<this paper's method label>):**
<equation or description>
where <symbol> is ...

**Diff:** <precise verb: replaced / added / dropped / rescaled ...> <exact term that changed>
**Insight:** <what dimension the After form wins on> + <what it costs>
```

If no prior method exists for a component, state so explicitly and skip the block.

- **Design details**: any specific hyperparameters, architectural choices, or engineering decisions the paper explicitly mentions. Do not invent details the paper does not state.

### Section 5: Key formulas (5-8 max)

Select the 5-8 most important equations from the paper. For each:

- The equation in LaTeX display math.
- A self-contained `where ... is ...` block (re-define every symbol even if defined earlier).
- **Paper location**: cite the equation number or section (e.g., "Eq. (3)", "Section 4.2").
- One sentence of insight: what this equation does and why it matters.

Do NOT attempt canonical-form-first derivations here — that is paper-reader's job. Just present the equation, define it, locate it, and give one-line insight.

### Section 6: Experiment results

- **Markdown tables** for the main experimental results. Reproduce the paper's key tables (simplified if needed) with the most important rows/columns.
- **Highlight**: bold the best numbers; add `(+X.X)` deltas where the paper reports improvements.
- One paragraph summarizing the experimental story: what was tested, what the main takeaway is.

### Section 7: Core contributions (3-5 bullet points)

Each bullet: one sentence stating what is new and why it matters. No elaboration — the detail is in Sections 3-4.

### Section 8: Limitations and future directions

- Limitations the paper itself acknowledges.
- Limitations you observe that the paper does not mention (label these clearly as "not discussed in paper").
- Future directions if the paper suggests them.

## Lightweight self-checks (run once after writing the full overview)

These are lighter than paper-reader's recursive loop. Run them once, fix issues, done — no recursive re-checking.

### Check 1: Formula spot-check

For every formula in Section 5, verify:
- [ ] `where` block is present and complete (every symbol defined).
- [ ] Paper equation number or section is cited.
- [ ] No symbol is used before being defined anywhere in the overview.

If any fail, fix immediately.

### Check 2: Source-fidelity scan

Read the paper's method section headings (not full text — just headings). For each heading, verify that Section 4 of the overview has a corresponding paragraph. If a method subsection is missing, add it.

### Check 3: Comparison-block coverage

For each item in Section 7 (contributions), verify that Section 4 has a Before/After/Diff/Insight block for it (or an explicit "no prior method" note). If missing, add it.

### Self-check report

Append a short block at the end of the overview file:

```
---
_Overview self-check:_
- Formula spot-check: <X/Y passed, Z fixed>
- Source-fidelity scan: <all method subsections covered / added: ...>
- Comparison-block coverage: <all contributions have Before/After or explicit skip>
```

## What this skill does NOT do

- **No recursive self-check loop.** One pass of checks, not the math-explain → zero-jump-check → concise-complete recursive loop. That is paper-reader's territory.
- **No canonical-form-first derivations.** Formulas are presented as-is from the paper, not derived from parent forms.
- **No chunk-by-chunk append-only protocol.** The overview is written as a single document, not incrementally.
- **No image-channel verification.** If page PNGs are available, the author may optionally cross-check formulas, but it is not mandatory (unlike paper-reader where it is).

## When invoked from paper-reader

When paper-reader invokes this skill:

1. Paper-reader passes the paper text (from `<paper_name>_temp/text.txt` or arxiv read) to this skill.
2. This skill writes `<paper_name>-overview.md`.
3. Paper-reader then proceeds with its own Step 2 (plan chunks), using the overview as additional context for planning and writing — the overview provides the global map that helps chunk-level writing stay coherent.
4. During chunk-by-chunk writing, paper-reader may reference the overview's analogies, comparison tables, and experiment data rather than re-deriving them from scratch.

## Standalone usage

When the user invokes this skill directly:

1. Read the paper (via pdf-ingest, arxiv MCP, or user-provided text).
2. Write the eight-section overview to `<paper_name>-overview.md`.
3. Run the three lightweight self-checks.
4. Tell the user where the file is and give a one-line orientation.
