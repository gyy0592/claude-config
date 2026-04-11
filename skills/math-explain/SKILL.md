---
name: math-explain
description: Rigorous mathematical explainer for a single concept, step, or equation. Use whenever the user asks to "explain mathematically", "show the derivation", "rewrite that with math", or whenever a previous explanation felt vague about a formula. Also invoke when paper-reader, pipeline-walk, or contrib-extract needs to introduce an equation — this skill is the canonical gate every formula must pass through. Trigger aggressively whenever a user pushes back on a prior explanation with "be more mathematical", "derive it", "where does this come from", or similar.
---

# math-explain

## Why this skill exists

Most formula explanations skip steps. The reader is forced to guess why a specialized equation was written down, what the symbols mean, which term drives the behavior, and when the formula breaks. This skill removes that guessing. Every formula that passes through this skill is introduced from its canonical parent, defined completely inline, dissected term by term, bounded by explicit assumptions, and — if it is an approximation — restored to its exact form so the reader sees what was dropped.

## Math formatting

Every variable, symbol, and equation — inline or display, including everything inside `where … is …` blocks and Diff/Insight lines — is written in LaTeX: `$x$` inline, `$$…$$` for display. Backticks are for file paths and code identifiers, never for math. Backticked math does not render and breaks downstream tools.

## The six-item checklist (every formula, no exceptions)

Before you write an equation, load this checklist into your head. After you write it, verify all five items are satisfied.

1. **Motivation + intuition** — one or two sentences stating *why* the formula exists. What is the physical or mathematical pressure that forces this shape? A reader who stops here should already feel the answer.
2. **Symbol definitions** — immediately after the equation, a `where ... is ..., ... is ...` block defining every symbol that appears in it. Re-define symbols even if they were defined earlier in the document; the reader must never flip back.
3. **Term-by-term insight** — walk through each term (and each index, each subscript, each weight). For each, state what it contributes to the whole. End with a one-sentence whole-formula insight.
4. **Assumptions and applicability** — explicit bullet list of every assumption that makes the formula valid (linearity, stationarity, i.i.d., small-angle, bounded domain, convexity, …). If the formula ceases to hold, it is one of these bullets that was violated.
5. **Approximation audit** — if the formula is an approximation, restore the exact un-approximated form above it, name the term(s) that were dropped, state their size relative to the kept terms, and give the strict validity regime (e.g. "valid for `ε ≪ 1`; the dropped `O(ε²)` term biases the result upward"). If the formula is exact, say "exact — no approximation".
6. **Paper location** — cite where this equation appears in the original paper (e.g. "Eq. (3)", "Section 2.1, second display equation"). When reporting self-check results, list this item explicitly so the reader can verify cross-referencing was done.

## Canonical-form-first rule

Never drop a specialized equation from the sky. The reader's trust comes from seeing the specialized form emerge from something they already know.

**Pattern:**

1. Write the canonical parent that any physics/ML/math reader knows ($F = ma$, $\nabla L = 0$, $p(x \mid y) \propto p(y \mid x)\,p(x)$, stochastic gradient update, etc.).
2. Write a symbol-to-symbol mapping from the paper's notation to the canonical notation.
3. Substitute and simplify, step by visible step, until you reach the paper's specialized form.
4. Only now label that final line as "the paper's equation (N)".

If you ever find yourself writing "the paper states equation X is ..." without doing steps 1–3, stop and restart.

**Non-universal concepts need their own derivation chain.** If the paper uses a tool or formalism that is itself specialized (e.g., Sparse Autoencoder, normalizing flow, Riemannian gradient, score matching), do not assume the reader knows it. Before you can use that tool as a building block, you must first derive or define it from something the reader *does* know. For example: if the paper uses a Top-K Sparse Autoencoder, the derivation chain is: standard autoencoder (reader knows this) → sparse autoencoder (add sparsity penalty, explain why) → Top-K SAE (replace penalty with hard Top-K gate, explain why). Only after this chain is complete can you use "Top-K SAE" as a known building block in subsequent formulas. Skipping intermediate links — e.g., jumping straight to "Top-K SAE" — is a concept-prerequisite gap (see `zero-jump-check`).

**Paper's original equations must be cited.** When the paper numbers an equation (e.g., Eq. 3, Eq. 7), the output must reference that number so the reader can cross-check against the original paper. Write "the paper's Eq. (3)" or similar after deriving the form. If the paper does not number its equations, reference by section and position (e.g., "the loss in Section 3.1, second display equation"). The reader must always be able to locate the original.

## Just-in-time introduction

Do NOT front-load a preliminaries section full of equations. Introduce each formula at the exact narrative moment it is needed. If you need gradient descent, write it at the step that does the gradient descent — not in a "background" block at the top.

## Self-contained symbol blocks

Every equation is followed by its own `where` block. Repetition across the document is expected and desired. The reader must never scroll up to recover a definition.

**Good:**

> The update rule is
>
> $$
> \theta \leftarrow \theta - \eta \, \nabla L(\theta)
> $$
>
> where $\theta$ is the current parameter vector, $\eta > 0$ is the learning rate, and $\nabla L(\theta)$ is the gradient of the loss evaluated at $\theta$.

**Bad** (symbol $\eta$ introduced ten pages ago, no re-definition; or symbols written in backticks, which do not render):

> The update rule is `θ ← θ − η ∇L(θ)`.

## Term-by-term dissection

Every index, subscript, weight, and constant is an invitation. Answer each invitation. "What does $M$ stand for? Why is $w_i$ designed this way? Why is the sum over $j$ and not $i$?" If you leave one of these unanswered, the reader has to invent the answer themselves, and they will invent wrong.

## Self-review before handing off

After writing the explanation, re-read it and test each of the five checklist items explicitly. If any item fails, expand the explanation on the spot — don't leave it for the reader to notice.

## When invoked by another skill

If `paper-reader`, `contrib-extract`, or `pipeline-walk` loads this skill mid-run, apply the checklist to whichever formula is currently being introduced in the chunk. The caller is responsible for deciding which formula; your job is to make that single formula bulletproof.
