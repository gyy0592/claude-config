---
name: no-undefined
description: Document-level rigour auditor. Enforces that every term, symbol, abbreviation, experimental label, and formula appears with its definition adjacent to its first occurrence — and re-states it on distant reuse. Also enforces no-step-skipping in math derivations. Invoke whenever writing or reviewing a technical report, paper explanation, or derivation where a reader could encounter an undefined token. Pairs with math-explain (single-formula checklist) and zero-jump-check (inter-step seam auditor) as the outer document-level layer of the rigorous-writing stack.
---

# no-undefined

## Why this skill exists

Readers lose trust the moment something appears without explanation. In a math derivation, an undefined symbol forces the reader to guess. In a technical report, an unexplained abbreviation or experimental label (J1, 3a, agg, mv, fix版…) feels like an in-joke the reader was not invited to. Both failures have the same root cause: the author assumed shared context that does not exist.

This skill removes that assumption entirely. **Nothing appears in the document without a definition immediately beside it.** Not in a glossary. Not in an appendix. Not in a prior section. Right there, in the same sentence.

This skill is the outer layer of a three-layer rigour stack:

| Layer | Skill | Scope |
|-------|-------|-------|
| Outer | `no-undefined` (this skill) | Entire document: every token of meaning has an adjacent definition |
| Middle | `zero-jump-check` | Derivation: every inter-step seam is nameable in one phrase |
| Inner | `math-explain` | Single formula: motivation, symbol defs, assumptions, approximation audit |

## The one rule

**Every token of meaning must carry its definition at its first occurrence, immediately adjacent — same sentence or the sentence immediately following.**

A "token of meaning" is anything a reader cannot decode from plain language alone:

- Technical terms and abbreviations (MoE, RL, agg, mv, GSM8K, RLHF…)
- Mathematical symbols ($\theta$, $\alpha$, $\mathbf{r}$, $\Delta$…)
- Experimental labels and codes (J1–J6, 3a/3b/3c/3d, Stage 1/2/3/4, fix 版…)
- Figure or table labels (Figure 11a, Figure A, Table 2…)
- Method names that are not transparent from plain language (weighted aggregation, majority vote, router logit bias…)
- Numbers or parameters that depend on context (K=4, alpha=0.01, top-8…)
- Measurement or benchmark names (pass@1, GSM8K前100样本…)

## Three sub-rules

### Sub-rule 1: Definition must be adjacent

Place the definition in parentheses immediately after the term's first occurrence in the document. A glossary section, footnote, or appendix does NOT substitute — the reader must never have to leave the current sentence to decode the term.

**Good:**
> K=4（每个输入做 4 次不同扰动参数的前向传播）聚合解码实测结果如下。

**Bad:**
> K=4 聚合解码实测结果如下。*(definition appears in a glossary 2 pages later)*

### Sub-rule 2: Re-define on distant reuse

If a term reappears more than **two ##-level sections** away from its first definition, re-state its definition inline as a brief parenthetical. "Brief" means 5–15 words — enough for the reader to recover context without flipping back.

**Good (distant reuse, 3 sections later):**
> 在 Stage 4 的 K=4（每个输入做 4 次前向传播）实验中…

**Bad:**
> 在 Stage 4 的 K=4 实验中… *(no reminder; reader must scroll back 3 sections)*

### Sub-rule 3: Math — "where" blocks are mandatory, no symbol escapes

For every formula, every symbol that appears in it must be defined in a `where … is …` block immediately below the formula — even if the symbol was defined earlier. Self-contained symbol blocks are expected and required. See `math-explain` for the full formula checklist (motivation, term-by-term dissection, assumptions, approximation audit, paper location).

**Good:**
> $$r_i = \sigma(W_r x_i)$$
> where $r_i$ is the router score for expert $i$, $\sigma$ is the sigmoid function, $W_r$ is the router weight matrix, and $x_i$ is the hidden state of the current token.

**Bad:**
> $$r_i = \sigma(W_r x_i)$$
> *(symbols defined three paragraphs earlier; reader must search)*

### Sub-rule 4: No formula drops from the sky

Never introduce a specialized formula without tracing it from a canonical parent the reader already knows. Write the canonical form first, map symbols, substitute step by step, then label the final line as the paper's or report's formula. See `math-explain` §Canonical-form-first rule. See `zero-jump-check` for auditing the inter-step seams of that derivation.

## How to apply this skill

### Mode A: Writing (proactive)

Before writing any sentence containing a token of meaning, run this decision tree:

```
Has this token appeared in this document before?
├── No  → write token（definition）inline, then continue
├── Yes, within the last 2 sections → use token without re-definition
└── Yes, more than 2 sections ago  → write token（brief reminder）inline
```

For math: apply `math-explain` to every formula; apply `zero-jump-check` to every inter-step seam.

For experimental labels: at the START of each new section that mentions a label (J1, 3a, etc.), re-state what it refers to if the label's first definition was in an earlier section.

### Mode B: Audit (reviewing existing text)

When invoked on existing text, run four passes:

**Pass 1 — Inventory.** Extract every token of meaning in document order. List each with its first occurrence location (section + approximate line).

**Pass 2 — Definition check.** For each token, inspect its first occurrence: is a definition immediately adjacent? Mark ✓ or ✗.

**Pass 3 — Distant-reuse check.** For each ✓ token, find all subsequent occurrences more than 2 sections away. Does each occurrence have a brief inline reminder? Mark ✓ or ✗.

**Pass 4 — Math audit.** For every formula, invoke `zero-jump-check` on its derivation chain. Flag any seam that cannot be named in one phrase.

**Report.** For every ✗ item: state its location, the token, and the exact parenthetical text to insert.

**Patch.** Apply all fixes with Edit tool. Verify chapter structure is unchanged after patching.

## What does NOT count as a definition

These patterns look like definitions but are not:

| Pattern | Why it fails |
|---------|--------------|
| `"MoE models use MoE routing"` | Circular — the term explains itself with itself |
| `"agg is defined in [3]"` | External reference — reader must leave the document |
| `"see Section 2 for K=4"` | Remote reference — reader must scroll back |
| Section title as implicit definition | A section titled "J5 Results" does not define "J5" — still needs parenthetical |
| Abbreviation expansion only | `"MoE (Mixture of Experts)"` is OK for the expansion, but must also add what it means architecturally if that is non-obvious |

## Self-check before handing off

After writing any section, verify each item before moving on:

- [ ] Every abbreviation/acronym has been defined in parentheses at first occurrence in this section (or re-stated if first defined more than 2 sections ago)
- [ ] Every experimental label (J1–J6, 3a–3d, fix版, etc.) has a parenthetical explanation at first use in this section
- [ ] Every mathematical symbol is defined in a `where` block immediately below its formula
- [ ] No formula was introduced without tracing it from a canonical parent
- [ ] Every inter-step seam in any derivation is nameable in one phrase
- [ ] No measurement or benchmark name appears without explaining what it measures and over what sample

If any box is unchecked, fix it before handing off — do not leave it for the reader to notice.
