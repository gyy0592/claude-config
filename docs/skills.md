[🇨🇳 中文版](skills.zh.md)

# Custom Skills Reference

All skills are installed via symlink (Step 4 in README). Trigger with the slash command or natural language.

## Standalone Skills

| Skill | Trigger |
|---|---|
| `gen-draft` | `/gen-draft`, "write draft", "generate draft" |
| `gen-report` | `/gen-report`, "write report", "summarize experiment" |
| `gen-report-detailed` | `/gen-report-detailed`, "detailed report", "full report" |
| `experiment-run` | `/experiment-run`, "run experiment", "submit job" |
| `claude-config-sync` | `/claude-config-sync`, "sync config", "push config" |
| `error-log` | `/error-log`, user frustration/anger at AI errors, cursing at mistakes |
| `follow-instruction` | `/follow-instruction`, AI violated instructions or made assumptions |
| `this-cluster` | Auto-consulted when writing Slurm scripts, choosing Python envs, or setting GPU flags |
| `codex-fix` | Auto-consulted on `codex review` failures: bwrap sandbox errors, stream disconnections |

## Paper Reader Suite (2 main + 6 sub-skills)

Two entry points:
- **Quick overview**: `/paper-overview`, "overview this paper" → 8-section structured overview (5-10 min)
- **Deep analysis**: `/read-paper`, `/paper-reader`, "read this paper" → chunk-by-chunk with recursive self-checks (30-60 min)

| Main Skill | Trigger | Purpose |
|---|---|---|
| `paper-overview` | `/paper-overview`, `/overview`, "quick analysis", "概览" | Fast structured overview: problem, method, results, 8 fixed sections |
| `paper-reader` | `/read-paper`, `/paper-reader`, "read this paper" | Deep analysis orchestrator for chunk-by-chunk precision

| Sub-Skill | Trigger | Purpose |
|---|---|---|
| `pdf-ingest` | Auto-invoked on PDF input | Dual-channel extraction: text + rendered page images |
| `prereq-probe` | Auto-invoked after ingest; or "probe my knowledge", "ask me what I know" | Scans for non-universal prerequisites, probes user knowledge via A/B/C questions, writes `knowledge_map.md` to control explanation depth |
| `contrib-extract` | "what are the contributions", `/contributions` | Four-ingredient rule (motivation, intuition, scenario, formula) |
| `pipeline-walk` | "walk me through this method", `/walk` | Stage-by-stage method walkthrough |
| `math-explain` | "explain mathematically", "show the derivation" | Rigorous per-equation explanation |
| `old-vs-new` | "compare A vs B" | Structured Before/After comparison |
| `zero-jump-check` | "fill in the missing steps", "audit this proof" | Inter-step logic audit |
| `concise-complete` | "tighten this", "make it denser" | Final language pass for information density |

## Dependency Trace Suite (1 + 2 sub-skills)

Entry point: `/dep-trace-launcher`, "trace dependencies"

Interactive launcher that collects parameters and dispatches to the tracing workers.

| Sub-Skill | Trigger | Purpose |
|---|---|---|
| `recursive-dep-trace` | `/recursive-dep-trace` | Single-entry recursive first-principles code tracing |
| `recursive-dep-trace-parallel` | `/recursive-dep-trace-parallel` | Parallel tracing with coordinated worker batches |
