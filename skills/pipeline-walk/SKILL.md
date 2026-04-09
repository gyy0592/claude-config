---
name: pipeline-walk
description: Walks a research paper's method stage by stage, in the paper's own logical order, with motivation + intuition + scenario + formula at every step and zero logical jumps between steps. Use when the user says "walk me through this method", "explain the algorithm step by step", "how does this actually work end to end", "explain the pipeline", "go through the forward/reverse process", or invokes /walk. Also invoked as the second stage of paper-reader after contrib-extract. Focuses on method mechanics — not novelty (contrib-extract does that).
---

# pipeline-walk

## Why this skill exists

A reader who has just seen "what is novel" (from `contrib-extract`) still does not know **how** the method runs end to end. This skill produces that: a stage-by-stage walkthrough of the paper's pipeline in the paper's own order, where every stage is motivated, intuited, scenario-grounded, mathematically formalized, and connected to the next stage by an explicit logical bridge.

## How to decompose the pipeline

1. Identify the paper's own ordering of the method. For a diffusion paper: forward process → single-step noising → multi-step noising (marginal) → reverse process → training objective → sampling. For an RL paper: environment → policy → value function → update rule → exploration. Use the paper's section/subsection structure as the starting skeleton and refine.
2. Make each stage one chunk. A chunk is small enough that the five-item formula checklist applies cleanly and large enough to stand on its own.
3. If a stage has sub-stages, recursively decompose (e.g. "forward process" → "single-step" → "multi-step").

## What every stage block contains

Exactly, in this order:

1. **Motivation.** Why does this stage exist? What would break if we skipped it? One short paragraph. **If this stage replaces, approximates, or modifies a traditional / exact / prior subroutine, load `~/.claude/skills/old-vs-new/SKILL.md` right here and produce one comparison block (Before / After / Diff / Insight) inside the motivation before moving on.** If the stage is genuinely novel with no prior counterpart, state that in one sentence and skip the block.
2. **Intuition + scenario.** The verbal/visual picture. Use a concrete analogy (a physical system, a toy setup, a one-dimensional example) so the reader can anchor.
3. **Canonical-form-first derivation.** Start from a form the reader already knows — gradient descent, Bayes rule, Markov chain, conservation law — and derive the paper's specialized form of this stage. Apply the full `math-explain` checklist to every equation introduced: parent form, symbol mapping, specialized form, self-contained `where` block, term-by-term insight, explicit assumptions, approximation audit. Load `~/.claude/skills/math-explain/SKILL.md` if you need a refresher on the checklist.
4. **Term dissection.** Walk each variable, index, weight, and constant in the equations. Answer "what does this symbol mean, why is it there, what would happen if it were different". Leave no symbol un-interrogated.
5. **Bridge to the next stage.** One sentence of motivation that forces the next stage to exist. This sentence is what `zero-jump-check` will audit.

## When a stage is a neural network

Describe it first as the abstract object $Y = f(x)$: what is $x$, what is $Y$, what does $f$ do. Then specify the concrete neural network: architecture family, training set, loss, training procedure, input format at train time, output format at train time, input format at inference time, output format at inference time. The reader must be able to swap the specific network for a different architecture without losing the story — that is the whole point of starting abstract.

## When a stage is an analytic solution

State the original problem it solves. If the problem is an optimization, write the optimization problem first (objective + constraints), then derive the closed form step by step, one algebraic move per line, each line tagged with the operation that produced it (expand, factor, set derivative to zero, apply Lagrangian, …). The derivation itself must pass `zero-jump-check`.

## Just-in-time formulas, self-contained symbol blocks

Do not front-load a preliminaries section. Introduce each equation at the exact stage where it is used. Re-define every symbol inline via `where ... is ..., ... is ...` — even if the symbol was defined in a previous stage. The reader must never flip back.

## Self-checks per chunk

After writing a stage block, run the three chunk-level self-checks and show the passes to the reader:

1. `math-explain` checklist on every equation in the stage (intra-formula rigor).
2. `zero-jump-check` on every seam inside the stage AND the seam from the previous stage to this one (inter-formula continuity).
3. `concise-complete` on every sentence in the stage (information-entropy maximization without loss).

Load each sub-skill from `~/.claude/skills/<name>/SKILL.md` the first time it is needed in the run.

## Boundary with contrib-extract

This skill does not re-enumerate the paper's novelty. It assumes the reader has already seen the contributions (from `contrib-extract`) and now wants the mechanics. If a stage happens to be a contribution, refer back to the contribution block by name instead of reproducing it.

## PDF verification

For every equation you are about to write, open the relevant page PNG from `pdf-ingest`'s temp dir and verify the symbols against the image. The text channel frequently mangles subscripts, superscripts, and Greek letters — the image is ground truth.

## Invocation from paper-reader

When `paper-reader` invokes this skill, write each stage as its own append-only chunk in the output file, run the three chunk-level self-checks immediately after writing, and then move to the next stage. See `paper-reader`'s execution protocol for details.
