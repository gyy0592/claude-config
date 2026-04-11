---
name: contrib-extract
description: Enumerates every distinct contribution/innovation of a research paper and explains each with the four-ingredient rule (motivation, intuition, scenario/example, core formula). Use when the user asks "what are the contributions of this paper", "what's novel here", "summarize the innovations", "what did they actually do that's new", or invokes /contributions. Also invoked as the first stage of paper-reader. Focuses exclusively on novelty — not pipeline mechanics (pipeline-walk does that).
---

# contrib-extract

## Why this skill exists

Authors usually bury their real contributions under boilerplate about related work, experimental tables, and paragraph-long abstract-rephrasings. A reader wants to know, in one pass, exactly what this paper does that no prior paper did, why it works, and where the crucial equation lives. This skill produces that.

## Output format — one block per contribution

For **every** distinct contribution in the paper, produce a block with exactly these four parts, in this order:

### Contribution N: <one-line headline>

**Type.** One of: new algorithm / first successful fusion of prior methods X and Y / clever reuse of prior idea Z to solve new problem W / new theoretical result / new empirical finding / new dataset or benchmark. State which, in one sentence.

**Motivation.** What problem was unsolved before this paper, and why did prior approaches fail? One short paragraph. The reader should finish this paragraph thinking "yes, that is a real gap".

**Old vs New (mandatory when a prior method exists).** Immediately after the motivation paragraph, load `~/.claude/skills/old-vs-new/SKILL.md` and produce one comparison block contrasting the prior method / exact form with this paper's version. The block must have the fixed Before / After / Diff / Insight shape defined by that skill. If (and only if) the contribution has no formula-level prior counterpart at all, state that explicitly in one sentence and skip the block — but the default is to include it.

**Intuition + scenario.** Explain the core idea in words first, grounded in a concrete scenario or analogy (physics setup, everyday example, toy ML problem). The reader should finish this paragraph able to re-derive the rough shape of the idea on a napkin. Do NOT write the equation yet — only the verbal/visual picture.

**Core formula.** Now — and only now — introduce the key equation that captures the contribution. Apply the `math-explain` checklist (load `~/.claude/skills/math-explain/SKILL.md` if you need a refresher): canonical parent form first, symbol-to-symbol mapping, specialized form, a self-contained `where ... is ..., ... is ...` block, term-by-term insight, explicit assumptions, and an approximation audit if the formula is an approximation. If a contribution has no single core equation (rare — most ML papers do), say so explicitly and give the most important mathematical object instead (the loss, the update rule, the bound).

## How to find the contributions

1. Read the abstract and introduction from the text channel of `pdf-ingest`.
2. Scan the paper for an explicit "our contributions" or "we propose" list. If the authors wrote one, start from that list but do not blindly trust it — authors often inflate.
3. Cross-check against the experimental claims and the method section. A real contribution is something the experiments measure and the method section implements.
4. Deduplicate: if two items are really the same idea described twice, merge them.
5. Drop items that are just restatements of prior work or routine engineering.
6. For every formula you are about to cite, open the corresponding page PNG from `pdf-ingest` and verify the symbols and indices against the image. The text channel frequently mangles subscripts.

## Source-fidelity check (run after writing each contribution block)

After writing a contribution block, re-read the corresponding section(s) of the paper paragraph by paragraph. For each paragraph, verify that every information bit below is either present in the block or explicitly irrelevant:

- **Design decisions**: every choice the authors made (architecture, hyperparameter range, data source, evaluation metric) and their stated rationale.
- **Design rationale**: every "because ..." or "this ensures ..." or "unlike standard X which does Y, we do Z" explanation.
- **Quantitative specifics**: exact numbers, ranges, thresholds, dataset sizes, model names, layer indices.
- **Hyperparameter-to-hypothesis mappings**: when an architectural choice directly encodes a scientific hypothesis (e.g., "dictionary size = number of mechanisms"), state the mapping explicitly.
- **Contrast with standard practice**: when the authors deliberately deviate from convention (e.g., using $D \ll d$ when standard practice is $D \gg d$), state both the convention and the deviation.

If any information bit is missing, add it to the block before running the three self-checks. This check is about *what information appears*, not *how it reads* — the language-level pass (`concise-complete`) comes later.

## Zero-jump and concise-complete apply to the prose too

After writing each contribution block, run the block through `zero-jump-check` (seams between the four parts must be obvious) and `concise-complete` (every sentence minimal but complete). Show the self-check pass, don't hide it.

## Boundary with pipeline-walk

This skill stops at "what is new and why". It does not walk the method step by step — that is `pipeline-walk`'s job. If a contribution is most naturally explained by the full pipeline, give a short pointer to the pipeline walkthrough instead of reproducing it.

## Invocation from paper-reader

When `paper-reader` invokes this skill, write each contribution block as its own append-only chunk into the output file, and run the chunk-level self-checks before moving to the next contribution. See `paper-reader`'s execution protocol for details.
