 [🇨🇳 中文版](README.zh.md)

# claude-config

Personal Claude Code configuration. Clone this repo and run two commands to fully restore on a new machine.

## Contents

| File | Purpose |
|---|---|
| `set_claude.sh` | Writes CLAUDE.md, all rule files, system_override.txt, and patches `.bashrc` with the `claude()` wrapper |
| `settings.json` | Plugin config — copy to `~/.claude/settings.json` as part of Step 3 |
| `skills/gen-draft/` | Custom global skill: generate high-level draft with dependency-aware execution order and observable outputs |
| `skills/gen-report/` | Custom global skill: concise experiment report |
| `skills/gen-report-detailed/` | Custom global skill: full 13-section detailed report |
| `skills/experiment-run/` | Custom global skill: config-driven experiment submission with structured output and recording |
| `skills/claude-config-sync/` | Custom global skill: sync this repo |
| `ten_commandments_for_ai_coding.md` | [📖 Ten Commandments for AI-Assisted Coding](ten_commandments_for_ai_coding.md) |

---

## Migration (new machine)

### Step 0 — Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Verify: `claude --version`

### Step 1 — Clone

```bash
git clone https://github.com/gyy0592/claude-config.git
cd claude-config
```

### Step 2 — Run setup script

```bash
bash set_claude.sh
source ~/.bashrc
```

This writes:
- `~/.claude/CLAUDE.md` — global instructions
- `~/.claude/rules/` — 3 rule files (artifacts, execution env, debug/autonomy)
- `~/.claude/system_override.txt` — system prompt injected on every `claude` call
- Patches `~/.bashrc` with `claude()` wrapper that auto-injects the system prompt

### Step 3 — Install plugins

Plugin installation is a **three-step process** that must happen inside Claude Code (all commands are slash commands, not terminal):

```bash
# Step 3a — Copy settings (run in terminal)
cp settings.json ~/.claude/settings.json

# Step 3b — Add marketplaces (run inside Claude Code)
/plugin marketplace add anthropics/skills
/plugin marketplace add humania-org/humanize
/plugin marketplace add openai/codex-plugin-cc

# Step 3c — Install plugins (run inside Claude Code)
/plugin install humanize@humania
/plugin install document-skills@anthropic-agent-skills
/plugin install claude-api@anthropic-agent-skills
/plugin install codex@openai-codex
```

> **Why this order?** `extraKnownMarketplaces` in `settings.json` enables discovery but `/plugin install` will fail unless `/plugin marketplace add` is run first.

| Plugin | Skills |
|---|---|
| `humanize@humania` | ask-codex, humanize, humanize-gen-plan, humanize-rlcr |
| `document-skills@anthropic-agent-skills` | pdf, docx, pptx, xlsx, frontend-design, canvas-design, algorithmic-art, brand-guidelines, doc-coauthoring, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing, claude-api |
| `claude-api@anthropic-agent-skills` | same 17 skills, claude-api variant |
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

---

## Keeping this repo up to date

```bash
cp ~/.claude/settings.json settings.json
cp -r ~/.claude/skills/gen-report skills/gen-report
cp -r ~/.claude/skills/gen-report-detailed skills/gen-report-detailed
cp ~/set_claude.sh set_claude.sh
git add -A && git commit -m "sync" && git push
```

---

## Credits

**Ten Commandments for AI-Assisted Coding** (`ten_commandments_for_ai_coding.md`) is adapted from the methodology of [Humanize](https://github.com/humania-org/humanize) by Dr. Sihao Liu, with personal modifications and additions. The original framework provides a structured approach to AI-assisted software development — the version in this repo incorporates project-specific extensions (e.g., Prerequisite-First execution ordering, observable output tracking).
