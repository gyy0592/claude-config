---
name: prereq-probe
description: Scans a paper for non-universal prerequisite concepts, builds a dependency tree, then uses AskUserQuestion to probe the user's knowledge from the top of the tree downward. Produces a knowledge_map file that controls explanation depth in downstream skills (paper-reader, pipeline-walk, contrib-extract). Use whenever a paper builds on specialized foundations (MoE, normalizing flows, score matching, SAEs, etc.) that the paper itself does not fully explain.
---

# prereq-probe

## Why this skill exists

A paper that improves MoE routing does not re-derive MoE from scratch. If the reader does not know MoE, every explanation of the improvement is incomprehensible — no amount of zero-jump patching inside the paper's own content can fix a gap that exists *before* the paper begins. Conversely, if the reader already knows MoE, inserting a full derivation wastes time and bloats the output.

This skill solves both problems by asking before writing: it maps the reader's actual knowledge boundary, then passes that map to downstream writing so each concept is expanded exactly as much as needed — no more, no less.

## What "universal" means

Universal knowledge = content covered in a standard undergraduate CS/ML curriculum:
- Mathematics: calculus (derivatives, chain rule, integrals), linear algebra (matrix multiply, eigenvalues, SVD), probability (expectation, conditional probability, Bayes' rule), basic statistics.
- ML fundamentals: feedforward neural network (forward pass, backprop, SGD), softmax, cross-entropy loss, train/val/test split, overfitting.
- Standard architectures: CNN (convolution, pooling), RNN/LSTM (hidden state, gating), Transformer (self-attention, multi-head attention, positional encoding), basic VAE (encoder-decoder, ELBO).

Everything outside this set is **non-universal** and requires probing.

## Output

A file `<paper_name>_temp/knowledge_map.md` with entries of this form:

```
## knowledge_map

- concept: <name>
  level: known | partial | unknown
  cascade_asked: yes | no
  notes: <optional — what the user said or what was inferred>

- concept: <name>
  ...
```

`known` = user confirmed understanding or the concept is universal.
`partial` = user knows the idea but not the details / math.
`unknown` = user said they do not know it, or it depends on a concept the user does not know.

## Execution protocol

### Phase 1 — Concept extraction

Scan `<paper_name>_temp/text.txt`. Look for:
1. Named methods or frameworks the paper assumes as context (e.g., "we build on MoE", "following the SAE literature", "using score matching").
2. Named losses, regularizers, or modules introduced without derivation (e.g., "load balancing loss", "auxiliary loss", "router z-loss").
3. Named problem settings that are not self-defined in the paper (e.g., "continuous-time MDPs", "POMDP", "belief space planning").
4. Any concept flagged as a concept-prerequisite gap by `zero-jump-check` in prior runs (if knowledge_map already exists, skip re-asking known concepts).

Do NOT include:
- Concepts the paper itself defines in full before using.
- Concepts in the universal set.
- Concepts the paper only cites in related work and never uses in the method.

Collect at most **7 concepts**. If more exist, prioritize the ones most central to understanding the paper's own contribution (i.e., concepts directly used in the method section, not just mentioned in intro).

### Phase 2 — Build the dependency tree

For each extracted concept, identify its direct prerequisite (what the reader must know *before* grasping this concept). Example:

```
MoE (Mixture of Experts)
  └── expert networks (specialized sub-networks)
       └── feedforward neural network  ← universal, stop here

Top-k sparse routing
  └── MoE  ← non-universal, need to check

Load balancing auxiliary loss
  └── Top-k sparse routing  ← non-universal, need to check
```

Stop a branch when it hits a universal concept. Universal concepts are assumed known — do not probe them.

Mark each concept as a **root** (no non-universal prerequisites in the tree) or **dependent** (depends on another non-universal concept).

### Phase 3 — Probe the user (top-down cascade)

Probe root concepts first. For each root concept, ask the user using `AskUserQuestion`:

**Question format:**
```
Do you know [concept name]?

A) Yes — I understand the idea and the math
B) Partially — I know the idea but not the details / formulas
C) No — I am not familiar with it
```

**Cascade rule:** If the user answers B or C for a concept X that has dependents Y₁, Y₂, …:
- Mark X as `partial` or `unknown`.
- Mark all dependents of X as `unknown` automatically — no need to ask them.
  - Reason: if the user does not know the prerequisite, they cannot know the dependent.

If the user answers A for X:
- Mark X as `known`.
- Ask about X's dependents normally (they may have their own non-universal sub-prerequisites).

**Batching rule:** If two concepts are siblings with the same prerequisite and the parent was already answered A, ask them together in one question:
```
Do you know [concept Y] and [concept Z]? (Both build on [concept X], which you said you know.)

A) Know both
B) Know Y but not Z
C) Know Z but not Y
D) Know neither
```

**Stop condition:** Stop probing when all non-universal concepts in the tree have a level assigned (either by asking or by cascade inference).

### Phase 4 — Write knowledge_map.md

Write `<paper_name>_temp/knowledge_map.md` following the format above. Include:
- Every concept probed, with its assigned level.
- Every concept inferred via cascade (label `cascade_asked: no` and add a note like "inferred unknown because prerequisite [X] is unknown").
- Concepts that turned out to be universal (do not list them — they are assumed known).

Print a one-line summary to the user:
```
prereq-probe complete: [N] concepts mapped. Expansion depths: [list concept → level].
```

## How downstream skills use knowledge_map

When writing a chunk that references a non-universal concept C:
1. Look up C in knowledge_map.
2. Apply the expansion rule:

| Level | Expansion |
|---|---|
| `known` | One-line definition + forward reference. No derivation. Example: "MoE routes each token to k experts; see [ref] for background." |
| `partial` | Definition paragraph + intuition + one key formula with `where` block. Skip the from-scratch derivation chain. |
| `unknown` | Full canonical-form-first derivation: motivation → intuition+scenario → parent form → term dissection → assumptions → approximation audit. Same depth as any paper-native formula. |

If a concept is not in knowledge_map (i.e., it was not identified in Phase 1), treat it as `unknown` by default and apply full expansion.

## Integration with zero-jump-check

When `zero-jump-check` flags a concept-prerequisite gap in a chunk, the patch depth is now determined by knowledge_map:
- `known`: patch = one-line reference ("recall that MoE routes tokens to experts via…")
- `partial`: patch = short definition paragraph
- `unknown`: patch = full derivation chain (same as a new formula)

This prevents `zero-jump-check` from always inserting full derivations regardless of what the user already knows.

## Standalone usage

The user may invoke this skill directly: "probe my knowledge before we start", "ask me what I know first", "check my background". In that case, run Phases 1–4 against the current paper (must be ingested first) and write the knowledge_map. Then tell the user where the map file is.

## Re-use across sessions

If `<paper_name>_temp/knowledge_map.md` already exists when paper-reader is invoked, skip Phase 3 (do not re-ask the user). Read the existing map directly and proceed. The user can force a re-probe by deleting the file.
