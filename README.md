 [🇨🇳 中文版](README.zh.md)

# claude-config

Personal Claude Code configuration. Clone this repo and run a few commands to fully restore on a new machine.

## Contents

| File | Purpose |
|---|---|
| `set_claude.sh` | Writes CLAUDE.md, all rule files, system_override.txt, patches `.bashrc` with the `claude()` wrapper and environment variables |
| `settings.json` | Plugin config — copy to `~/.claude/settings.json` as part of Step 3 |
| `setup_codex.sh` | Codex CLI setup — configures `~/.codex/config.toml` and `auth.json` with API key rotation |
| `codex_info.yaml.template` | Template for Codex API credentials (copy to `codex_info.yaml` and fill in your keys) |
| `skills/gen-draft/` | Custom global skill: generate high-level draft with dependency-aware execution order and observable outputs |
| `skills/gen-report/` | Custom global skill: concise experiment report |
| `skills/gen-report-detailed/` | Custom global skill: full 13-section detailed report |
| `skills/experiment-run/` | Custom global skill: config-driven experiment submission with structured output and recording |
| `skills/claude-config-sync/` | Custom global skill: sync this repo |
| `skills/dep-trace-launcher/` | Custom global skill: interactive launcher for recursive dependency tracing |
| `skills/recursive-dep-trace/` | Custom global skill: single-entry recursive first-principles code tracing |
| `skills/recursive-dep-trace-parallel/` | Custom global skill: parallel recursive dependency tracing with worker batches |
| `skills/paper-reader/` + 7 sub-skills | **Paper / long-text reading suite**: orchestrates `pdf-ingest`, `contrib-extract`, `pipeline-walk`, `math-explain`, `old-vs-new`, `zero-jump-check`, `concise-complete` into a chunk-by-chunk, motivation-first, zero-logical-jump explainer |
| `ten_commandments_for_ai_coding.md` | [Ten Commandments for AI-Assisted Coding](ten_commandments_for_ai_coding.md) |

---

## Migration (new machine)

### Step 0 — Install Claude Code and Codex CLI

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Install Codex CLI (required for the Humanize automated pipeline)
npm install -g @openai/codex
```

Verify: `claude --version` and `codex --version`

### Step 1 — Clone

```bash
git clone https://github.com/gyy0592/claude-config.git
cd claude-config
```

### Step 2 — Run setup scripts

```bash
# 2a — Claude Code setup
bash set_claude.sh
source ~/.bashrc

# 2b — Codex CLI setup (configure API endpoint and key)
cp codex_info.yaml.template codex_info.yaml
# Edit codex_info.yaml: fill in your base_url and api_key in the 'now' section
bash setup_codex.sh
```

`set_claude.sh` writes:
- `~/.claude/CLAUDE.md` — global instructions
- `~/.claude/rules/` — 3 rule files (artifacts, execution env, debug/autonomy)
- `~/.claude/system_override.txt` — system prompt injected on every `claude` call
- Patches `~/.bashrc` with `claude()` wrapper and environment variables:
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — enables agent teams for parallel development
  - `HUMANIZE_CODEX_BYPASS_SANDBOX=true` — bypasses Codex sandbox (required on HPC/containers without landlock)

`setup_codex.sh` writes:
- `~/.codex/config.toml` — model provider configuration
- `~/.codex/auth.json` — API key
- Rotates previous credentials (now → last1 → last2 → last3 → last4)

### Step 3 — Install plugins

Plugin installation is a **three-step process** that must happen inside Claude Code (all commands are slash commands, not terminal):

```bash
# Step 3a — Copy settings (run in terminal)
cp settings.json ~/.claude/settings.json

# Step 3b — Add marketplaces (run inside Claude Code)
/plugin marketplace add humania-org/humanize
/plugin marketplace add openai/codex-plugin-cc

# Step 3c — Install plugins (run inside Claude Code)
/plugin install humanize@humania
/plugin install codex@openai-codex
```

> **Why this order?** `extraKnownMarketplaces` in `settings.json` enables discovery but `/plugin install` will fail unless `/plugin marketplace add` is run first.

| Plugin | Skills |
|---|---|
| `humanize@humania` | gen-plan, start-rlcr-loop, refine-plan, start-pr-loop, ask-codex |
| `codex@openai-codex` | codex CLI integration |

### Step 4 — Install custom global skills

```bash
mkdir -p ~/.claude/skills
# Symlink each skill so edits in the repo are reflected immediately
for s in skills/*/; do
  name=$(basename "$s")
  ln -sfn "$(pwd)/skills/$name" ~/.claude/skills/"$name"
done
```

| Skill | Trigger |
|---|---|
| `gen-draft` | `/gen-draft`, "write draft", "generate draft" |
| `gen-report` | `/gen-report`, "write report", "summarize experiment" |
| `gen-report-detailed` | `/gen-report-detailed`, "detailed report", "full report" |
| `experiment-run` | `/experiment-run`, "run experiment", "submit job" |
| `claude-config-sync` | `/claude-config-sync`, "sync config", "push config" |
| `this-cluster` | Auto-consulted when writing Slurm scripts, choosing Python envs, or setting GPU flags |
| `codex-fix` | Auto-consulted on `codex review` failures: bwrap sandbox errors, stream disconnections |
| `dep-trace-launcher` | `/dep-trace-launcher`, "trace dependencies" — interactive launcher |
| `recursive-dep-trace` | `/recursive-dep-trace` — single-entry recursive code tracing |
| `recursive-dep-trace-parallel` | `/recursive-dep-trace-parallel` — parallel recursive tracing with worker batches |
| `paper-reader` | `/read-paper`, `/paper-reader`, "read this paper" — full pipeline |
| `pdf-ingest` | Auto-invoked whenever a PDF is the input (text + rendered page images in one shot) |
| `contrib-extract` | "what are the contributions", "what's novel here", `/contributions` — four-ingredient rule |
| `pipeline-walk` | "walk me through this method", "step by step", `/walk` — stage-by-stage method walkthrough |
| `math-explain` | "explain mathematically", "show the derivation", "be more rigorous" — per-equation gate |
| `old-vs-new` | "compare A vs B", "why is this better than the exact form" — Before/After delta |
| `zero-jump-check` | "this skips steps", "fill in the missing steps", "audit this proof" — inter-step logic audit |
| `concise-complete` | "tighten this", "kill the filler", "make it denser" — final language pass |

---

## Automated Development Workflow

This config's core automation feature is the **Humanize pipeline**: a closed-loop system where Claude implements code and Codex reviews it iteratively until all acceptance criteria are met. The full workflow is:

```
draft.md → gen-plan → plan.md → RLCR loop → done
```

### Step 1: Write a Draft (`/gen-draft`)

Create a `draft.md` that describes **what** you want to build and **why**. The draft should include:

- **Goal**: What the feature/fix/refactor should accomplish
- **Known Facts / Constraints**: Important context that the planner must respect. Examples:
  - "Use `codex-fix` skill if bwrap sandbox errors occur"
  - "Follow `experiment-run` conventions for output directory structure"
  - "GPU memory must stay under 24GB"
  - "Must be compatible with Python 3.10+"
- **Acceptance criteria** (optional rough version — gen-plan will formalize them)

```bash
/gen-draft
```

### Step 2: Generate an Implementation Plan (`/humanize:gen-plan`)

Transforms the draft into a structured plan with acceptance criteria, task breakdown, and path boundaries. Claude and Codex debate the plan in multiple convergence rounds.

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md
```

Review the generated plan. If you have comments, annotate with `CMT: ... ENDCMT` blocks and run:

```bash
/humanize:refine-plan --input docs/plan.md
```

### Step 3: Run the RLCR Loop (`/humanize:start-rlcr-loop`)

The RLCR (Review-Loop-Code-Review) loop automates implementation with iterative Codex review:

```bash
/humanize:start-rlcr-loop docs/plan.md --codex-model gpt-5.3-codex --max 5
```

**Parameters explained:**
- `docs/plan.md` — path to the plan file
- `--codex-model gpt-5.3-codex` — Codex model to use for reviews
- `--max 5` — maximum number of iterations before auto-stop

**How the loop works:**
1. Claude implements tasks from the plan (`coding` tag → Claude, `analyze` tag → Codex)
2. Claude writes a summary of the work done
3. Codex reviews the summary — if issues found, Claude gets feedback and continues
4. When Codex outputs "COMPLETE", the loop enters Review Phase
5. `codex review` performs code review with `[P0-9]` severity markers
6. If issues found, Claude fixes them and continues
7. Loop ends when no issues remain or max iterations reached

**Other useful flags:**
- `--yolo` — skip the plan understanding quiz and let Claude answer Codex's questions directly (full automation)
- `--skip-quiz` — skip the quiz only
- `--agent-teams` — enable parallel development with Claude Code Agent Teams
- `--skip-impl` — skip to code review only (useful for reviewing existing changes)

### One-Shot Workflow (Plan + Loop in One Command)

If you trust the plan generation process, you can go from draft to implementation in one command:

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md --auto-start-rlcr-if-converged
```

This starts the RLCR loop automatically when the plan converges without unresolved disagreements.

### Monitoring Progress

```bash
# Add to your .bashrc or .zshrc (one-time setup)
source ~/.claude/plugins/cache/humania/humanize/*/scripts/humanize.sh

# Monitor RLCR loop progress in a separate terminal
humanize monitor rlcr
```

### Cancellation

```bash
/humanize:cancel-rlcr-loop
```

---

## Keeping this repo up to date

```bash
cp ~/.claude/settings.json settings.json
# Sync every tracked custom skill back from ~/.claude/skills/
for s in skills/*/; do
  name=$(basename "$s")
  [ -d ~/.claude/skills/"$name" ] && rsync -a --delete ~/.claude/skills/"$name"/ skills/"$name"/
done
cp ~/set_claude.sh set_claude.sh
git add -A && git commit -m "sync" && git push
```

---

## Credits

**Ten Commandments for AI-Assisted Coding** (`ten_commandments_for_ai_coding.md`) is adapted from the methodology of [Humanize](https://github.com/humania-org/humanize) by Dr. Sihao Liu, with personal modifications and additions. The original framework provides a structured approach to AI-assisted software development — the version in this repo incorporates project-specific extensions (e.g., Prerequisite-First execution ordering, observable output tracking).
