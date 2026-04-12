---
name: paper-reader
description: Reads an academic paper end to end and produces two files — a reader-friendly overview (`<paper_name>-overview.md`) and a mathematically rigorous deep read (`<paper_name>-output.md`) with zero logical jumps. Use ONLY when the user explicitly invokes `/read-paper`, `/paper-reader`, or says "read this paper", "解析这篇文章", "读这篇论文". Never auto-trigger from keywords alone. The skill orchestrates eight sub-skills (pdf-ingest, prereq-probe, paper-overview, contrib-extract, pipeline-walk, math-explain, zero-jump-check, concise-complete) in a strict protocol: ingest → prereq probe → overview → chunk-by-chunk deep read with visible per-chunk self-checks.
---

# paper-reader (main orchestrator)

## Goal

Read an academic paper and produce two markdown files:

1. `<paper_name>-overview.md` — a reader-friendly eight-section overview (via `paper-overview` sub-skill).
2. `<paper_name>-output.md` — a mathematically rigorous deep read with chunk-by-chunk self-checks.

The deep-read output file `<paper_name>-output.md`:

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
| `prereq-probe` | `~/.claude/skills/prereq-probe/SKILL.md` | Step 1.2: scan for non-universal prerequisites, probe user knowledge, write knowledge_map. |
| `paper-overview` | `~/.claude/skills/paper-overview/SKILL.md` | Step 1.5: eight-section reader-friendly overview (written before the deep read). |
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

### Step 1.2 — Prerequisite probe (prereq-probe)

After ingestion and before the overview, scan the paper for non-universal prerequisite concepts and map the user's knowledge.

1. Load `~/.claude/skills/prereq-probe/SKILL.md`.
2. If `<paper_name>_temp/knowledge_map.md` already exists, skip to step 4 — do not re-ask the user.
3. Run prereq-probe Phases 1–4:
   - Extract non-universal concepts from `text.txt` (max 7).
   - Build the dependency tree.
   - Use `AskUserQuestion` to probe user knowledge top-down (cascade infers dependents automatically).
   - Write `<paper_name>_temp/knowledge_map.md`.
4. Read `knowledge_map.md` into working memory. All subsequent writing steps consult this map to control expansion depth.

**Why before the overview:** The overview (Step 1.5) already needs to decide how deeply to explain background concepts. If the overview is written before knowledge is mapped, it must guess the reader's level — and guessing wrong produces either a bloated tutorial or an incomprehensible summary.

**What happens if there are no non-universal concepts:** Skip the AskUserQuestion phase. Write an empty knowledge_map (just the header) and continue. Do not ask the user pointless questions.

### Step 1.5 — Overview (paper-overview)

After ingestion and before the deep read, produce a reader-friendly overview of the entire paper by invoking `paper-overview`. This step:

1. Load `~/.claude/skills/paper-overview/SKILL.md`.
2. Using the paper text (from `<paper_name>_temp/text.txt` or the arxiv read result), write `<paper_name>-overview.md` following paper-overview's eight-section structure and lightweight self-checks.
3. The overview is a **standalone deliverable** — it is written to its own file, not into `<paper_name>-output.md`.

**Why this step exists:** The overview builds a global map of the paper (problem context, key concepts with analogies, structured Before/After comparisons, experiment tables) before the chunk-by-chunk deep read begins. This global map serves two purposes:
- The user gets an immediately useful quick-read document.
- The subsequent chunk-level writing (Steps 2–3) can reference the overview's analogies, comparison blocks, and data tables rather than re-deriving them, improving coherence and reducing redundancy.

**During chunk-by-chunk writing (Step 3):** When writing contribution or pipeline chunks, you may reference the overview file for:
- Intuitive analogies already established (reuse or refine them, don't contradict).
- Before/After comparison blocks (the deep read's `old-vs-new` blocks should be consistent with the overview's, but more detailed).
- Experiment numbers (the overview's tables are the quick reference; the deep read cites them when relevant).

Do NOT copy-paste from the overview into the output. The output must stand alone — but the overview informs its writing.

### Step 2 — Plan the chunks

Read `text.txt` (fast scan: abstract, introduction, method headings, conclusion). Produce an ordered list:

1. Contribution chunks: one per distinct contribution, extracted following `contrib-extract`.
2. Pipeline chunks: one per pipeline stage, in the paper's own order, following `pipeline-walk`.

Write this list at the top of `<paper_name>-output.md` as a visible table of contents so the reader knows what is coming.

### Step 3 — Chunk loop (this is the heart of the protocol)

For each chunk in order:

1. **Write the chunk.** Use `contrib-extract` for contribution chunks or `pipeline-walk` for pipeline chunks. Append the chunk to `<paper_name>-output.md` — never overwrite existing chunks. Before writing any non-universal concept, look it up in `knowledge_map.md` and apply the expansion rule: `known` → one-line reference; `partial` → definition + intuition + one formula; `unknown` → full canonical-form derivation chain. If the concept is not in knowledge_map, treat it as `unknown`.
2. **Verify formulas against the image channel.** For every equation you wrote, open the corresponding `page-NN.png` with the `Read` tool and verify the symbols/subscripts. If the text channel mangled anything, correct it using the image as ground truth.
3. **Source-fidelity check.** Re-read the corresponding section(s) of the paper paragraph by paragraph. Verify that every design decision, design rationale, quantitative specific, hyperparameter-to-hypothesis mapping, and contrast-with-standard-practice in the paper is present in the chunk. If anything is missing, add it to the chunk now, before running the self-checks. (See `contrib-extract`'s source-fidelity check section for the full checklist.)
4. **Recursive self-check loop.** Run all three self-checks on the chunk. If any check triggers a modification, re-run ALL three checks on the modified chunk. Repeat until a full pass produces zero modifications. The reason for re-running all three: a `zero-jump-check` patch may insert new formulas that need `math-explain` treatment; a `math-explain` expansion may add text that needs `concise-complete` pruning; a `concise-complete` rewrite may create a new seam that `zero-jump-check` must audit.

   ```
   LOOP:
     modified = false
     (a) math-explain checklist — every formula has canonical-form derivation
         (including the non-universal-concept chain: if a concept like SAE is
         used, verify it was derived from a known parent before first use),
         self-contained `where` block, term-by-term insight, explicit assumptions,
         approximation audit, paper equation number cited.
         → If any formula fails: expand the chunk. Set modified = true.
     (b) zero-jump-check — every seam inside the chunk AND the seam from the
         previous chunk to this one, INCLUDING concept-prerequisite gaps
         (a concept used but never introduced from known foundations).
         → If any jump found: insert intermediate steps. Set modified = true.
     (c) concise-complete — every sentence minimal, no filler, no ambiguous
         pronouns, all subjects/verbs/objects intact.
         → If any sentence rewritten: set modified = true.
     IF modified → go to LOOP
     ELSE → all checks pass, exit loop
   ```

5. **Show the self-check pass to the user.** Append a short "self-check pass" block under the chunk listing what was found and what was fixed in each iteration of the loop. The user must see the work. If the loop ran more than one iteration, show each iteration's findings. Empty passes (nothing to fix) are still listed as "no issues".
6. **Append only.** If a later chunk reveals a problem in an earlier chunk, do NOT silently rewrite the earlier chunk. Append a clearly-marked correction block at the end of the affected chunk.

### Step 4 — Final hand-off

When every chunk has been written and passed all three self-checks, tell the user:

- Where the overview file is (`<paper_name>-overview.md`) — the quick-read version.
- Where the deep-read file is (`<paper_name>-output.md`) — the formula-level version.
- Where the temp dir is (`<paper_name>_temp/`) and that it may be kept or deleted.
- A one-line summary of the paper (not a replacement for the outputs, just an orientation line).

Answer follow-up questions from the user using the same four-ingredient + zero-jump + concise-complete rules. Follow-ups are not exempt.

## Output file structure

```
# <Paper title (always in the paper's original language — never translate)> — paper-reader output

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

- **Chunk-by-chunk, never whole-document at once.** One chunk written, checks run in recursive loop, checks shown, next chunk.
- **Source-fidelity before self-checks.** Re-read the paper paragraph by paragraph and verify every information bit is present before running the three self-checks. Missing information cannot be caught by language-level or formula-level checks.
- **Recursive self-check loop, not single-pass.** If any self-check triggers a modification, re-run ALL three checks. Repeat until a full pass produces zero modifications. A single-pass check misses cross-skill dependencies (e.g., a zero-jump patch inserting a new formula that needs math-explain treatment).
- **Every chunk gets all three checks.** No skipping math-explain, no skipping zero-jump-check, no skipping concise-complete.
- **knowledge_map controls expansion depth.** For every non-universal concept, look it up in `knowledge_map.md` before writing. Apply the expansion rule from prereq-probe: `known` → one-line reference; `partial` → definition + intuition + one formula; `unknown` → full canonical-form derivation chain. Never write a full derivation for a concept the user already knows, and never skip one for a concept they do not.
- **Non-universal concepts need derivation chains.** If the paper uses a specialized tool (SAE, normalizing flow, score matching, etc.), derive or define it from something the reader knows before using it. This is enforced by both math-explain (canonical-form-first) and zero-jump-check (concept-prerequisite gap).
- **Paper equation numbers must be cited.** When the paper numbers an equation, reference that number in the output so the reader can cross-check.
- **Image channel is ground truth for every formula.** Don't trust `pdftotext` output for an equation you haven't cross-referenced against the page PNG.
- **Contributions first, then full pipeline. Always.** No abbreviated mode. No "skip the pipeline".
- **Append only.** Earlier chunks are preserved as written; corrections are appended, not overwritten.
- **Self-check passes are visible.** The user must be able to see what was audited and what was fixed, for every chunk. If the recursive loop ran multiple iterations, show each iteration.

## Why this protocol

Each rule exists because skipping it produces a specific, visible failure:

- **Without chunk-by-chunk**, the writer drifts toward "summarize everything at once" and loses the motivation-first rhythm.
- **Without source-fidelity check**, design decisions, rationales, and quantitative specifics from the paper get silently dropped — and no downstream check catches the omission because they only audit what was written, not what should have been written.
- **Without the recursive loop**, a zero-jump patch may insert a new formula that never gets math-explain treatment, or a math-explain expansion may bloat text that concise-complete never prunes.
- **Without math-explain per chunk**, formulas get dropped with undefined symbols or no assumptions.
- **Without zero-jump-check per chunk**, adjacent steps drift apart and the reader gets stranded — including concept-prerequisite gaps where a specialized tool is used without introduction.
- **Without concise-complete per chunk**, the output bloats and the user has to reread sentences.
- **Without the image channel**, text-channel subscript errors propagate into the explanation unchecked.
- **Without append-only**, the user loses visibility into what changed and why.
- **Without prereq-probe**, expansion depth is guessed: too shallow strands the novice reader at the first specialized concept; too deep wastes the expert reader's time with derivations they already own. prereq-probe eliminates the guess.
