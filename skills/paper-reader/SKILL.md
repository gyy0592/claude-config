---
name: paper-reader
description: Reads an academic paper end to end and produces a boilerplate-free, motivation-first, mathematically rigorous explanation with zero logical jumps — written to `<paper_name>-output.md`. Use ONLY when the user explicitly invokes `/read-paper`, `/paper-reader`, or says "read this paper", "解析这篇文章", "读这篇论文". Never auto-trigger from keywords alone. The skill orchestrates six sub-skills (pdf-ingest, contrib-extract, pipeline-walk, math-explain, zero-jump-check, concise-complete) in a strict chunk-by-chunk protocol with visible per-chunk self-checks. Output is always contributions first, then the full pipeline walkthrough.
---

# paper-reader (main orchestrator)

## Goal

Read an academic paper and write a single markdown file `<paper_name>-output.md` that:

- Strips boilerplate (related-work surveys, marketing, generic background, uninformative tables).
- Explains every contribution and every pipeline stage with four ingredients: **motivation, intuition, scenario/example, formula**.
- Introduces every formula from its canonical parent form, with a self-contained `where ... is ...` block, term-by-term dissection, explicit assumptions, and an approximation audit.
- Connects every point to the next with an explicit logical bridge so the reader never has to guess why a new step appears.
- Shows its self-check passes to the reader so the user can see which formulas were expanded, which transitions were patched, and which sentences were rewritten.

Default output language is **English**. If the user writes the request in another language or explicitly asks for a language, follow the user.

## Trigger

Command-only. Activate ONLY on explicit user invocation (`/read-paper`, `/paper-reader`, "read this paper", "解析这篇文章", "读这篇论文"). Do NOT auto-activate just because a PDF is in the conversation — the user has to ask.

## Sub-skills this orchestrator composes

Load each sub-skill's SKILL.md from `~/.claude/skills/<name>/SKILL.md` the first time you need it in a run. The sub-skills are independent — any of them can also be called directly by the user in any other context.

| Sub-skill | Path | Role here |
|---|---|---|
| `pdf-ingest` | `~/.claude/skills/pdf-ingest/SKILL.md` | Step 1: dual-channel extraction from the PDF. |
| `contrib-extract` | `~/.claude/skills/contrib-extract/SKILL.md` | Step 2: one chunk per contribution, novelty-focused. |
| `pipeline-walk` | `~/.claude/skills/pipeline-walk/SKILL.md` | Step 3: one chunk per pipeline stage, in the paper's own order. |
| `math-explain` | `~/.claude/skills/math-explain/SKILL.md` | Per-chunk check #1: intra-formula rigor (the five-item checklist). |
| `zero-jump-check` | `~/.claude/skills/zero-jump-check/SKILL.md` | Per-chunk check #2: inter-formula continuity. |
| `concise-complete` | `~/.claude/skills/concise-complete/SKILL.md` | Per-chunk check #3: information-entropy maximization without loss. |

## Execution protocol (non-negotiable)

### Step 0 — Determine the paper and output name

- If the user handed over a PDF path, set `paper_name` to the PDF basename without extension (e.g. `2501.11873v2.pdf` → `paper_name = 2501.11873v2`).
- If the user pasted text or gave a link, derive `paper_name` from the paper title (short, lowercase, hyphenated).
- The output file is `<paper_name>-output.md` in the current working directory.
- The scratch directory for intermediate artifacts is `<paper_name>_temp/` in the current working directory.

### Step 1 — Ingest (pdf-ingest)

If the input is a PDF: run `bash ~/.claude/skills/pdf-ingest/scripts/ingest.sh <paper>.pdf`. This produces `<paper_name>_temp/text.txt` and `<paper_name>_temp/page-NN.png`. Do not begin explanation until both channels exist.

If the input is already text, create the temp dir yourself and dump the text into `<paper_name>_temp/text.txt`. No image channel in that case — note this in the output file and rely on the text alone.

### Step 2 — Plan the chunks

Read `text.txt` (fast scan: abstract, introduction, method headings, conclusion). Produce an ordered list:

1. Contribution chunks: one per distinct contribution, extracted following `contrib-extract`.
2. Pipeline chunks: one per pipeline stage, in the paper's own order, following `pipeline-walk`.

Write this list at the top of `<paper_name>-output.md` as a visible table of contents so the reader knows what is coming.

### Step 3 — Chunk loop (this is the heart of the protocol)

For each chunk in order:

1. **Write the chunk.** Use `contrib-extract` for contribution chunks or `pipeline-walk` for pipeline chunks. Append the chunk to `<paper_name>-output.md` — never overwrite existing chunks.
2. **Verify formulas against the image channel.** For every equation you wrote, open the corresponding `page-NN.png` with the `Read` tool and verify the symbols/subscripts. If the text channel mangled anything, correct it using the image as ground truth.
3. **Run all three self-checks, in this order, on the chunk you just wrote.** None may be skipped. Marking a chunk "done" without all three is a protocol violation.
   1. `math-explain` checklist — every formula in the chunk has canonical-form derivation, self-contained `where` block, term-by-term insight, explicit assumptions, approximation audit.
   2. `zero-jump-check` — every seam inside the chunk AND the seam from the previous chunk to this one. Patch any jump by inserting intermediate steps until every seam is immediately obvious.
   3. `concise-complete` — every sentence minimal, no filler, no ambiguous pronouns, all subjects/verbs/objects intact.
4. **Show the self-check pass to the user.** Append a short "self-check pass" block under the chunk listing what was found and what was fixed. The user must see the work. Empty passes (nothing to fix) are still listed as "no issues".
5. **Append only.** If a later chunk reveals a problem in an earlier chunk, do NOT silently rewrite the earlier chunk. Append a clearly-marked correction block at the end of the affected chunk.

### Step 4 — Final hand-off

When every chunk has been written and passed all three self-checks, tell the user:

- Where the output file is (`<paper_name>-output.md`).
- Where the temp dir is (`<paper_name>_temp/`) and that it may be kept or deleted.
- A one-line summary of the paper (not a replacement for the output, just an orientation line).

Answer follow-up questions from the user using the same four-ingredient + zero-jump + concise-complete rules. Follow-ups are not exempt.

## Output file structure

```
# <Paper title> — paper-reader output

<optional one-line citation>

## Table of contents
- Contributions
  - C1: ...
  - C2: ...
- Pipeline
  - Stage 1: ...
  - Stage 2: ...
  - ...

## Contributions

### C1: <headline>
<contrib-extract block: motivation / intuition+scenario / core formula with full math-explain treatment>

_self-check pass (C1):_
- math-explain: ...
- zero-jump-check: ...
- concise-complete: ...

### C2: ...

## Pipeline

### Stage 1: <name>
<pipeline-walk block: motivation / intuition+scenario / canonical-form-first derivation / term dissection / bridge to next stage>

_self-check pass (Stage 1):_
- math-explain: ...
- zero-jump-check: ...
- concise-complete: ...

### Stage 2: ...
```

## Hard rules (repeat because they matter)

- **Chunk-by-chunk, never whole-document at once.** One chunk written, three checks run, checks shown, next chunk.
- **Every chunk gets all three checks.** No skipping math-explain, no skipping zero-jump-check, no skipping concise-complete.
- **Image channel is ground truth for every formula.** Don't trust `pdftotext` output for an equation you haven't cross-referenced against the page PNG.
- **Contributions first, then full pipeline. Always.** No abbreviated mode. No "skip the pipeline".
- **Append only.** Earlier chunks are preserved as written; corrections are appended, not overwritten.
- **Self-check passes are visible.** The user must be able to see what was audited and what was fixed, for every chunk.

## Why this protocol

Each rule exists because skipping it produces a specific, visible failure:

- **Without chunk-by-chunk**, the writer drifts toward "summarize everything at once" and loses the motivation-first rhythm.
- **Without math-explain per chunk**, formulas get dropped with undefined symbols or no assumptions.
- **Without zero-jump-check per chunk**, adjacent steps drift apart and the reader gets stranded.
- **Without concise-complete per chunk**, the output bloats and the user has to reread sentences.
- **Without the image channel**, text-channel subscript errors propagate into the explanation unchecked.
- **Without append-only**, the user loses visibility into what changed and why.
