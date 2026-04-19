---
name: tech-report-digest
description: Digest technical reports, system white papers, system cards, and long research briefs into a navigable markdown that separates what actually works from what is merely claimed, extracts the complete pitfall dossier, audits every ablation table for fairness and load-bearingness, and surfaces the concrete recipes a reader can copy. Use this skill whenever the user hands over a long technical document (NVIDIA/DeepSeek/Meta model reports, company engineering post-mortems, product system cards, multi-page research search briefs) and asks to "digest", "read this report", "summarize what actually works in this", "tell me what they actually did", "pull out the real lessons", "extract the pitfalls", "整理这份报告", "消化这篇技术报告", "哪些是真的 work 哪些是吹牛", or similar. Trigger aggressively for any document that is product/system-focused, is long (>10 pages or >3000 words), contains multiple design decisions + ablations + engineering tradeoffs, and where the reader needs to tell signal from noise. Do NOT trigger for short arxiv math papers (use paper-reader) or lecture slides (use lecture-notes).
---

# tech-report-digest

## Goal

Produce `<report_name>-digest.md`: a single navigable markdown document that reads a long technical report the way an experienced engineer re-reads it — asking "what is validated vs asserted", "what did they try that failed", "is this ablation fair", "can I actually copy this". The document must be built so the reader can jump directly to any section via a table-of-contents with clickable anchors, and return to the TOC from any section with one click.

This skill is the gap between `paper-reader` (academic papers — math-heavy, contribution + pipeline) and `lecture-notes` (teaching material — exam-ready). Technical reports have different pathology: their narrative often lists features ("we also have X, we also have Y") instead of tracing causal chains, they mix solid empirical validation with unsupported marketing, they hide the most valuable negative evidence in single sentences ("we observed 40% flush-to-zero when quantizing Mamba output"), and their ablation tables often compare configurations that are not controlled for. The digest's job is to reorganize all of this into a form where signal is unmistakable.

Default output language is **whatever language the user wrote their request in**. If the user wrote Chinese, the digest is Chinese; English stays English.

## Trigger

Activate when the input is a technical report / white paper / system card / long engineering brief — signals include:
- Long (>10 pages or >3000 words)
- Product or system focused, not a single algorithm
- Contains multiple design decisions with accompanying ablations
- Has failure modes mentioned in passing ("we observed", "naively", "caused instability")
- User asks to "digest", "summarize what really works", "tell me the real lessons", or hands over a report and asks for an organized read

Do NOT activate for:
- Short academic papers with a clear theorem / method / experiment structure → `paper-reader`
- Lecture slide decks / teaching material → `lecture-notes`
- Single-function code review → not this skill

## Output file structure

This is a hard contract. Every digest follows this layout. Anchors use the exact IDs shown so navigation is guaranteed to work across markdown renderers.

```markdown
# <Report Title> — Digest

<one-line citation or source>

<a id="toc"></a>
## Table of Contents
- [§0. Logic chain (read this first)](#s0)
- [§1. Big claims registry](#s1)
- [§2. Component deep-read](#s2)
- [§3. Pitfall dossier](#s3)
- [§4. Ablation audit](#s4)
- [§5. Transferable takeaways](#s5)
- [§6. Counterfactuals & open questions](#s6)

---

<a id="s0"></a>
## §0. Logic chain (read this first)

<ASCII flow + 3–5 sentence causal story>

<sub>[↑ back to TOC](#toc)</sub>

---

<a id="s1"></a>
## §1. Big claims registry

<grading table: Validated / Supported / Asserted-only × Recipe / Insight / Hype>

<sub>[↑ back to TOC](#toc)</sub>

---

<a id="s2"></a>
## §2. Component deep-read

### 2.1 <Component A>
- **Motivation**: …
- **Paths tried (including failed)**: …
- **Failure mode + root cause (if any)**: …
- **Final design**: …
- **Ablation anchor**: see §4.X
- **Signal grade**: Validated / Supported / Asserted

### 2.2 <Component B>
…

<sub>[↑ back to TOC](#toc)</sub>

---

<a id="s3"></a>
## §3. Pitfall dossier

<one-page table of every negative observation in the report>

<sub>[↑ back to TOC](#toc)</sub>

---

<a id="s4"></a>
## §4. Ablation audit

### 4.1 <Table / Figure reference>
- **Intent**: what question does this ablation answer?
- **Controls**: is the comparison fair? (params / data / compute / seeds)
- **Effect size**: meaningful? relative magnitude
- **Over-claim check**: does the paper's conclusion exceed the evidence?
- **Load-bearing**: would the paper's story survive without this?
- **Verdict**: Strong / OK / Weak / Cosmetic

<sub>[↑ back to TOC](#toc)</sub>

---

<a id="s5"></a>
## §5. Transferable takeaways

**Recipe (copy-paste values):**
- …

**Insight (design principles):**
- …

**Hype (handle with suspicion):**
- …

<sub>[↑ back to TOC](#toc)</sub>

---

<a id="s6"></a>
## §6. Counterfactuals & open questions

- **If they had not done X, what would break?** …
- **Why no ablation on Y?** …
- **What would a follow-up have to prove?** …

<sub>[↑ back to TOC](#toc)</sub>
```

Two non-negotiable formatting rules:
1. **Every** section header has `<a id="sXY"></a>` immediately above it. The TOC links to these IDs.
2. **Every** section ends with `<sub>[↑ back to TOC](#toc)</sub>` so the reader can return from anywhere with one click.

If the renderer strips raw HTML, the fallback GitHub-style anchor (`#0-logic-chain-read-this-first`) still works; the explicit IDs are belt-and-braces.

## Execution protocol

### Step 0 — Scope and naming
- Set `report_name` from PDF basename or from the report title (short, hyphenated, lowercase).
- Output file: `<report_name>-digest.md` in the current working directory. If the report already has `<report_name>-overview.md` / `-output.md` siblings (paper-reader outputs), that is fine — the digest is a separate deliverable with a different job.
- Scratch dir: `<report_name>_temp/` (reuse if pdf-ingest already populated it).

### Step 1 — Ingest
If input is a PDF and `<report_name>_temp/text.txt` does not exist, run `bash ~/.claude/skills/pdf-ingest/scripts/ingest.sh <report>.pdf`. If input is already text or the temp dir is populated, skip. Page images are optional but useful for verifying numerical tables.

### Step 2 — Negative-evidence scan (do this BEFORE writing anything)

The pitfall dossier (§3) is the skill's highest-leverage section, and pitfalls are the easiest thing to miss if you write §2 first and §3 as an afterthought. Scan the full text for negative-evidence patterns and collect the raw sentences into the scratch dir as `<report_name>_temp/pitfall-raw.md`. This is the input to §3.

Keyword pool (use grep / Grep with these, case-insensitive):

```
English: naively, observed that, did not, could not, failed, unstable,
         degraded, degradation, regressed, collapse, collapsed, diverge,
         diverged, NaN, catastrophic, flush (to zero), drift, blew up,
         broke, brittle, surprisingly, counter-intuitive, unexpected,
         challenge, difficulty, however, but we found, overhead, bottleneck,
         hurt, worse than, underperformed, disappointing

Chinese: 崩, 不稳定, 失败, 退化, 爆, 飞, 掉, 出现问题, 漏, 踩坑,
          意外, 不能, 无法, 出乎意料, 反直觉, 下降, 变差
```

For each hit, save: line, containing sentence, and which section it came from. De-duplicate. Flag any sentence that describes an **observed failure** (not just a general caveat); those become §3 entries.

### Step 3 — Claim inventory
Scan abstract, introduction, and each §/subsection's first and last paragraphs. For every assertion that sounds load-bearing, file it with:
- Exact wording (short quote)
- Where supported: section, table, figure, or "citation only"
- Grade (see Grading rubrics below)

Save as `<report_name>_temp/claims-raw.md`. This is input to §1.

### Step 4 — Component map
List every design decision / module / subsystem the report discusses (architecture components, precision recipe items, training-pipeline stages, post-training tricks, inference tricks). For each, note:
- Section where it is introduced
- Does it have an ablation? Which table?
- Does it have a pitfall story? Pull from Step 2 output.

This becomes the skeleton of §2.

### Step 5 — Write §1 through §6 in this order
Write in this exact order. Do **not** start with §0.

1. **§1 Big claims registry** — fill the table from Step 3 output, applying the Grading rubrics.
2. **§2 Component deep-read** — one subsection per entry from Step 4. For each, always include the failure-path story if Step 2 surfaced one. If no failure story, explicitly write "No failure path documented in this report" — the absence is itself information.
3. **§3 Pitfall dossier** — one table row per item from Step 2 output, with columns: Observation · Trigger condition · Reported root cause · Mitigation in paper · Transferability.
4. **§4 Ablation audit** — one subsection per ablation table/figure. Use the Ablation audit checklist below. Assign a verdict.
5. **§5 Transferable takeaways** — three lists. See Recipe / Insight / Hype rubric below.
6. **§6 Counterfactuals & open questions** — list the questions the report did not answer. At minimum: (a) one "if they had not done X" per major component, (b) one "why no ablation on Y" per suspicious gap found in Step 4, (c) any contradictions or trade-offs glossed over.

### Step 6 — Write §0 LAST
Only after §1–§6 exist can the logic chain be drawn honestly. §0 must:
- Open with a 5–10-line ASCII flow diagram showing: root problem → framework → main claims → bottlenecks encountered → solutions.
- Follow with 3–5 sentences of plain narrative tracing the same causal story.
- If the report's original narrative is poor ("we have X, we have Y, we have Z"), explicitly rewrite to a causal chain. State in one sentence that the narrative was restructured.

### Step 7 — Final pass
- Verify every section has its `<a id="sX">` anchor and its `[↑ back to TOC](#toc)` footer.
- Run the self-check listed below.
- If the user wrote Chinese, the output is Chinese. If English, English. Match the user.

## Grading rubrics (reference tables)

### Claim level (§1 column 2)

| Grade | Meaning | Example |
|---|---|---|
| **Validated** | Has a dedicated ablation with controls named, numerical deltas shown, and the delta is large enough to survive seed noise | "LatentMoE +2–5 pts across 5 benchmarks at matched active params (Table 1)" |
| **Supported** | Has a figure / curve / single data point but not a controlled ablation, or the ablation exists but controls are loose | "MTP improves validation loss (Fig. X)" |
| **Asserted** | Narrative claim without empirical support in this document | "Simultaneous multi-env RL is more stable than staged" — no ablation shown |

### Transferability level (§1 column 3, §5)

| Grade | Meaning |
|---|---|
| **Recipe** | Exact numerical/code-level values a reader could copy (e.g. "top-K=22, ℓ=1024", "last 15% high-precision", "α=1e-6") |
| **Insight** | Qualitative design principle portable beyond the exact values (e.g. "shrink routed dim, reinvest in more experts") |
| **Hype** | Marketing-adjacent language without operational content (e.g. "state-of-the-art", "novel approach", "best-in-class") |

### Ablation audit checklist (§4 per entry)

For every ablation table / figure, answer each of these. A "no" answer on any is evidence against the ablation being load-bearing.

1. **Intent**: what specific question does this ablation answer? (One sentence.)
2. **Controls matched**: are parameters / data / compute / seeds / hyperparameters the same across rows? List what is matched and what is not.
3. **Effect size**: is the delta meaningful? Give relative magnitude. Ignore differences < typical seed noise unless the paper reports multiple seeds.
4. **Benchmark choice**: are the benchmarks chosen to cover the claim or to cherry-pick strong cases?
5. **Over-claim check**: is the text's conclusion narrower than, equal to, or wider than the data supports?
6. **Load-bearing**: would the paper's narrative survive if this ablation were removed?

**Verdicts:**
- **Strong** — all six pass, load-bearing, can be cited as support
- **OK** — minor gaps, still defensible
- **Weak** — one or more serious gaps (unfair controls, over-claim, tiny delta)
- **Cosmetic** — present to look thorough but does not actually test the claim

## Hard rules

- **Pitfall dossier is non-negotiable.** Every digest has §3. If the scan finds nothing, write "no documented failure paths surfaced in text scan" — the absence is itself important information. Do not silently skip the section.
- **§0 is written last.** The logic chain is only honest after the components, pitfalls, and ablations have been audited.
- **Every claim in §1 has an evidence pointer.** No free-floating assertions. If the evidence is "citation only", mark it Asserted.
- **Anchors are literal `<a id="sX">` HTML tags, not just markdown headers.** Back-to-TOC links must appear at the end of every top-level section. Guaranteed navigation is the skill's core UX feature.
- **Match the user's language.** Chinese request → Chinese digest. Never auto-translate.
- **Do not invent failures or numbers.** If a pitfall or ablation is ambiguous in the source, flag it as such in the relevant section rather than filling in plausible-sounding detail.
- **Do not copy the report's feature-list narrative.** The skill exists because that narrative is inadequate. Reorganize into causal chains in §0 and §2.

## Self-check (after final draft)

Run **all** these checks. Fix anything that fails before handing off to the user. Check (A) is the "no dropped content" audit the reader cares most about.

### (A) Completeness audit — the non-negotiable one

A digest that misses a pitfall or ablation is worse than useless, because it looks authoritative. Do this audit **before** the shape/vocabulary checks:

1. **Enumerate the paper's surface.** Run three greps (or manual scans) against the full text:
   - `grep -E "Table [0-9]+|Figure [0-9]+|Fig\. [0-9]+"` → list of every table and figure.
   - The negative-evidence keyword pool from Step 2 → list of every sentence describing an observed failure.
   - Abstract + introduction + each section's first/last paragraph → list of every load-bearing claim.
2. **Cross-check the digest.** For each enumerated item, locate it in the digest:
   - Every **Table/Figure that reports a measurement or ablation** must appear in §4 with a verdict (architecture block diagrams and marketing headline charts are exempt but must be explicitly noted as exempt).
   - Every **observed-failure sentence** from the Step-2 pitfall-raw.md must appear in §3 as a dossier row (consolidation is fine; silent omission is not).
   - Every **load-bearing claim** from Step-3 claims-raw.md must appear in §1 with a grade.
3. **Emit a coverage table at the bottom of the digest** (new mandatory appendix — see template below). Any row marked "✗ missed" must either be added back to the relevant section, or have an explicit one-line justification for why it was excluded (e.g. "Fig 3 is architecture diagram, not an ablation").

### (B) Shape and vocabulary checks

4. **Navigation works**: click TOC links in your head — does every link resolve to an existing `<a id>`? Does every section end with a back-to-TOC footer?
5. **Pitfall dossier ≥ 3 entries OR explicit empty-set note.** A 10+ page tech report with zero pitfalls is almost always a scanning miss.
6. **At least one "Weak" or "Cosmetic" ablation verdict.** If every ablation is Strong, you are probably not auditing hard enough.
7. **At least one "Hype" item in §5.** White papers almost always contain some marketing language; if you found none, re-read §1/§2 looking for unsupported superlatives.
8. **At least one counterfactual in §6** per major component identified in Step 4.

### (C) User-needs mapping — prove the digest actually serves the reader

The reader usually wants six things from a long report: (1) all key points, (2) all conclusions, (3) every pitfall they hit, (4) how they solved each problem, (5) every ablation they ran, (6) what actually works vs what is just stated. Before handing off, fill this tiny table so the reader can trust the digest:

| Need | Where in this digest | Count |
|---|---|---|
| ① All key claims | §1 rows | N (same as claims-raw.md count) |
| ② All conclusions | §1 + §5 Takeaways | M |
| ③ Every pitfall they hit | §3 rows | K (same as pitfall-raw.md observed-failure count) |
| ④ How they solved each problem | §2 "Final design" per component | P (= number of components in §2) |
| ⑤ Every ablation | §4 subsections | Q (= number of measurement Tables/Figures, exemptions noted) |
| ⑥ Work vs noise | §1 grade column + §5 Recipe/Insight/Hype split | — |

If any cell cannot be filled honestly, the digest is not done.

## Mandatory appendix: coverage table

Every digest ends with this appendix — right after §6 and before any self-check pass note. This is the reader's proof of completeness.

```markdown
## Appendix: coverage audit

**Tables / Figures in source** (from grep):
- Table 1 — ✅ §4.2 (verdict: Strong)
- Table 2 — ✅ §4.4 (verdict: OK)
- Figure 3 — ⊘ exempt (architecture diagram, not a measurement)
- …

**Observed-failure sentences** (from pitfall-raw.md):
- "We observed … 40% flush-to-zero …" — ✅ §3 row P1
- "did not observe need for staged …" — ✅ §3 row P11 (reframed as reverse-lesson)
- …

**Load-bearing claims** (from claims-raw.md):
- "best-in-class throughput" — ✅ §1 row 1 (Validated)
- "25T tokens stable" — ✅ §1 row 18 (Asserted)
- …

If any item is ✗ (missed) and not ⊘ (explicitly exempted), the digest is incomplete.
```

## Sub-skills this orchestrator may call

Load these on demand, not pre-emptively:

| Sub-skill | When |
|---|---|
| `pdf-ingest` | Step 1, if input is PDF and temp dir is empty |
| `math-explain` | Inside §2 if a component involves a formula that needs a canonical form + `where` block |
| `old-vs-new` | Inside §2 if a component is most naturally explained as a delta from prior art |
| `concise-complete` | Final language-level pass once Steps 5–7 are done, if any paragraphs feel bloated |

Do NOT call `zero-jump-check` — this skill does not enforce mathematical continuity; it enforces engineering-path clarity, which is a different contract.

## Why this protocol exists (rationales)

Each rule traces to a specific failure mode observed when writing digests ad hoc:

- **Pitfall-scan-before-write** prevents the common failure where the writer drafts §2 based on the report's polished self-description and then can't find where to put the negative evidence. Pre-loading the pitfalls into a scratch file forces them into §2 and §3 by construction.
- **§0 written last** prevents a plausible-sounding but inaccurate logic chain. The chain can only be drawn after the components have been audited; writing it first biases every later section to confirm it.
- **Signal-vs-noise grading** is what separates a digest from a summary. A summary preserves the report's original confidence levels; a digest restores calibration.
- **Ablation audit with verdicts including "Cosmetic"** forces an explicit judgment that many technical reports include ablations mostly for optics. Without the Cosmetic verdict, every ablation defaults to looking like support.
- **Counterfactuals** are where the real research questions live; a digest that lists only what the report did is a report-as-mirror, not a report-as-critique.
- **Explicit HTML anchors + back-to-TOC links** exist because the digest is often long and the reader needs to jump around while reading other documents; the navigation UX is part of the product, not decoration.

## One-line trigger test

If the user has handed you a >10-page product/system report and said "tell me what really works in this", this skill applies. If they handed you a 6-page math paper with one theorem, route to `paper-reader`.
