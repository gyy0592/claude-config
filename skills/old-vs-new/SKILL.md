---
name: old-vs-new
description: Writes a structured Before/After comparison that makes the mathematical and conceptual delta between two approaches immediately visible. Use whenever the user wants to contrast a new method with prior art, a closed form with its approximation, method A vs method B, or "old way vs new way" — e.g. "compare Adam vs SGD mathematically", "standard softmax vs log-sum-exp trick", "why is this approximation better than the exact form", "what changed from LBL to global-batch LBL". Also invoked by contrib-extract and pipeline-walk whenever their motivation has a prior-method or exact-form counterpart. Domain-agnostic: works on any two things that can be written as equations.
---

# old-vs-new

## Why this skill exists

Motivation is most convincing when the reader can **see the delta**. Saying "this is better because …" without the old form next to the new form asks the reader to trust on faith. Putting the two forms side by side, with an explicit one-line diff and a one-line insight, turns the motivation into something the reader verifies with their own eyes.

This skill does **only one thing**: it writes the comparison skeleton. It does not verify the formulas inside the two sides — that is `math-explain`'s job, and this skill calls it. It does not audit sentence quality — that is `concise-complete`'s job. It does not audit logical seams — that is `zero-jump-check`'s job. Strict single responsibility.

## When to invoke it

Any of the following is a trigger:

- A paper's contribution is "replace prior method X with new method Y".
- A derivation introduces an approximation of an exact form.
- A pipeline stage drops a traditional subroutine in favor of a new one.
- The user asks for a mathematical comparison between two named things.

If **no** prior method or exact form exists (e.g. a genuinely first-ever algorithm with no baseline), say so explicitly and skip this skill for that block.

## The comparison block — fixed shape

Every comparison you produce has exactly these four parts, in this order. Do not reorder and do not rename.

```
**Before (prior method / exact form):** <one-line label — what this is and who used it>

<equation>

where <symbol> is …, <symbol> is …, …

**After (this paper / approximation):** <one-line label>

<equation>

where <symbol> is …, <symbol> is …, …

**Diff:** <one line that names exactly which term was changed / added / removed / replaced. Use a precise verb (replaced, added, dropped, rescaled, swapped, generalized) — not "is different" or "changed".>

**Insight:** <one line that explains why the After form wins on the dimension the paper cares about, and what it costs. The cost must be named, even if small.>
```

The `where` blocks are self-contained: re-define every symbol inside the block even if it appeared earlier in the document, so the reader never has to scroll back.

## Delegation — what this skill does NOT do itself

- **Formula rigor inside Before and inside After:** both equations are subject to the full `math-explain` checklist. When you write the Before equation, mentally (or literally) load `~/.claude/skills/math-explain/SKILL.md` and apply its five-item checklist to that equation. Do the same for After. This skill guarantees only that both sides exist and are contrasted; it does not certify the contents of either side.
- **Language quality:** the finished block is subject to `concise-complete` as usual.
- **Logical seam between Before and After and the surrounding text:** `zero-jump-check` audits that seam, not this skill.

The point of this delegation is that if `math-explain` changes its checklist later, this skill automatically benefits without being edited.

## The Diff line — precision rules

The Diff is the load-bearing line of the whole block. A vague Diff kills the comparison. Rules:

1. Start with a precise verb: **replaced**, **added**, **dropped**, **rescaled**, **swapped**, **generalized**, **specialized**, **restricted**, **relaxed**.
2. Name the exact term or operator that changed, in the same notation as the equations above. Don't paraphrase it in words — point at the symbol.
3. If more than one change exists, list them as a short comma-separated sequence of precise verbs; do not hide multiple changes behind one fuzzy verb.

**Good:**
> **Diff:** replaced the per-micro-batch average `(1/B) Σ f_i` with the per-global-batch average `(1/G) Σ f_i`; `G ≫ B`.

**Bad:**
> **Diff:** changed how the loss is computed.

## The Insight line — precision rules

1. State the dimension the After form wins on, named concretely (convergence speed, memory, sample efficiency, variance of the estimator, bias, numerical stability, parallelism, …).
2. Name the cost. Every real change has a cost — compute, memory, communication, bias, additional hyperparameter, loss of a theoretical guarantee. If you cannot name a cost, the comparison is probably wrong; re-read the paper.

**Good:**
> **Insight:** averaging over the global batch widens the i.i.d. support of $f_i$, so the balance constraint becomes statistical rather than per-sequence, which permits expert specialization; cost is one extra all-reduce per step.

**Bad:**
> **Insight:** the new method is better.

## When there is no clean canonical "Before"

If the paper compares to a whole family of prior methods instead of one specific form, write the Before as the **most general prior form** that covers the family, and say so in its label. If the paper's contribution is purely empirical with no formula-level delta, use words only in Before/After but still write Diff and Insight — skipping Diff/Insight is not allowed.

## How other skills invoke this

- `contrib-extract`: the motivation part of every contribution block that has a prior method must include an `old-vs-new` block before the contribution's own core formula. If the paper has no prior-method counterpart for a contribution, the skill states so explicitly in the motivation and skips the block for that contribution.
- `pipeline-walk`: any pipeline stage whose motivation is "we replace the traditional X with Y" must include an `old-vs-new` block in the stage's motivation part, before the stage's own derivation.
- Both callers still run the three chunk-level self-checks (`math-explain`, `zero-jump-check`, `concise-complete`) on the full chunk afterwards; this skill does not replace any of them.

## Standalone usage

When the user says "compare A vs B mathematically" or similar, produce one comparison block using the fixed shape above. Nothing more, nothing less. If the user asks for multiple comparisons in one reply, produce one block per comparison and separate them with a blank line.
