---
name: zero-jump-check
description: Logic-level auditor that scans a derivation or argument for non-obvious leaps between adjacent steps and patches them by inserting intermediate steps until every transition is immediately obvious. Use as the inter-formula self-check inside paper-reader, math-explain, pipeline-walk, and contrib-extract. Also use standalone whenever the user says things like "this derivation skips steps", "I don't see how you got from A to B", "be more rigorous", "check for logical jumps", "audit this proof", "fill in the missing steps". Complements math-explain, which audits a single formula in isolation.
---

# zero-jump-check

## Why this skill exists

Every formula on its own can be correct and still leave the reader stranded, because the leap *between* formulas is too large. Readers lose trust the instant they cannot reconstruct a transition. This skill is the dedicated auditor for those transitions. It does not judge individual formulas — `math-explain` does that. It judges the seam between formulas, and between claims.

## The single rule

For every pair of adjacent steps `(A, B)` in a derivation or argument, the move from `A` to `B` must be **immediately obvious** to a reader who understands `A`. "Immediately obvious" means the reader can state the operation that takes `A` to `B` in one short phrase — "expand the square", "apply the chain rule", "substitute definition of `p(y|x)`", "bound by triangle inequality", "drop the `O(ε²)` term because `ε ≪ 1`". If the reader cannot state that phrase, the transition is a jump and must be patched.

## How to run the audit

1. **Extract the sequence.** List the steps in order — every equation, every claim, every inferential move. Number them `S1, S2, …, Sn`.
2. **Prerequisite scan (before seam scanning).** For each step `Sk`, ask: does `Sk` introduce a concept, tool, or method that has not been defined earlier in the document from something the reader already knows? If yes, flag it as a concept-prerequisite gap. This is a jump even if there is no adjacent step to compare against — the gap is between the reader's knowledge and the step itself.
3. **Scan each seam.** For each pair `(Sk, Sk+1)`, ask: what single operation takes `Sk` to `Sk+1`? Write that operation down in one phrase.
4. **Flag the jumps.** If you cannot produce the phrase, OR if the phrase hides more than one non-trivial operation (e.g. "simplify" is not a phrase, it is a euphemism for several operations), mark the seam as a jump.
5. **Patch each jump.** For every flagged seam (including concept-prerequisite gaps from step 2), insert one or more intermediate steps `Sk.1, Sk.2, …` between `Sk` and `Sk+1` — or before `Sk` for prerequisite gaps — until every new seam passes the rule. Patching is recursive: if a newly inserted step creates a new non-obvious seam, patch that too.
6. **Report what you did.** List the seams you patched and what you inserted, so the caller can show the pass to the user.

## What counts as "not a jump"

- A single algebraic manipulation whose name a reader would recognize (expand, collect, factor, distribute, substitute definition X).
- Application of a single named rule (chain rule, integration by parts, Bayes' rule, triangle inequality, Jensen's inequality, Markov property).
- A purely notational rewrite (rename index, move a constant outside a sum).
- A definition plugged in, when the definition is visible in the same paragraph.

## What counts as a jump

- "Simplifying" from a three-line expression to a one-line expression without showing the cancellations.
- Swapping the order of a sum and an integral without stating Fubini and its hypotheses.
- Introducing an approximation without naming which term was dropped and why it is small.
- Using a result from a named lemma/theorem without saying which lemma and verifying its hypotheses.
- **Concept-prerequisite gap:** introducing a tool, method, or formalism (e.g. "Sparse Autoencoder", "Langevin dynamics", "Riemannian gradient") that a reader with standard ML/math/physics training would not know, without first defining it from something the reader does know. The test: if you removed the term's name and left only its formula, would the reader recognize it as a special case of something familiar? If not, the concept needs an introduction before you use it. This is distinct from algebraic jumps — it is a *knowledge* jump, and it is just as fatal to comprehension.
- Any move that combines two or more of the above in one step.

## Boundary with math-explain

This skill does **not** re-verify that a single formula is fully motivated, fully symbol-defined, or fully term-dissected. That is `math-explain`'s job. If the formula itself is broken, hand the work back to `math-explain` after you are done patching the seams. The two skills run as a pair: `math-explain` for intra-formula rigor, `zero-jump-check` for inter-formula continuity.

## How other skills invoke this

`paper-reader` runs this skill on every chunk after the chunk is written, including the seam between the previous chunk and the new one. The output is a visible re-check pass: a list of patched seams with the inserted intermediate steps.

## Standalone usage

When the user points at a derivation and says "audit this" or "where did you skip a step", run steps 1–5 above and return the patched version plus the list of patched seams.
