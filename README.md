 [🇨🇳 中文版](README.zh.md)

# claude-config

Personal Claude Code configuration with automated development pipeline. Clone and run to restore on a new machine.

---

## Quick Start

### 1. Install prerequisites

```bash
npm install -g @anthropic-ai/claude-code
npm install -g @openai/codex
```

### 2. Clone and setup

```bash
git clone https://github.com/gyy0592/claude-config.git
cd claude-config

# Claude Code: writes CLAUDE.md, rules, system_override, and patches shell rc
bash set_claude.sh && source "${ZDOTDIR:-$HOME}/.zshrc" 2>/dev/null || source ~/.bashrc

# Codex CLI: fill in your base_url and api_key, then run setup
cp codex_info.yaml.template codex_info.yaml
# Edit codex_info.yaml → fill the 'now' section
bash setup_codex.sh
```

### 3. Install plugins (inside Claude Code)

```bash
cp settings.json ~/.claude/settings.json

# Run these inside Claude Code (slash commands, not terminal)
/plugin marketplace add humania-org/humanize
/plugin marketplace add openai/codex-plugin-cc
/plugin install humanize@humania
/plugin install codex@openai-codex
```

### 4. Install custom skills

```bash
mkdir -p ~/.claude/skills
for s in skills/*/; do
  ln -sfn "$(pwd)/skills/$(basename "$s")" ~/.claude/skills/"$(basename "$s")"
done
```

See [docs/skills.md](docs/skills.md) for the full skill list and triggers.

---

## Automated Development Workflow

The core feature: a **Humanize pipeline** where Claude codes and Codex reviews in a closed loop.

```
draft.md  →  gen-plan  →  plan.md  →  RLCR loop  →  done
```

### Step 1: Write a Draft

Create `draft.md` describing **what** and **why**. Include:

- **Goal** — what the feature/fix should accomplish
- **Known Facts / Constraints** — e.g. "GPU memory < 24GB", "follow `experiment-run` output conventions", "Python 3.10+"
- **Rough acceptance criteria** (gen-plan will formalize them)

```bash
/gen-draft
```

### Step 2: Generate a Plan

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md
```

### Step 3: Review the Plan

**Do not skip this.** Read the plan. Verify acceptance criteria, task breakdown, path boundaries. If you have feedback, annotate with `CMT: ... ENDCMT` and refine:

```bash
/humanize:refine-plan --input docs/plan.md
```

Repeat until the plan is correct. The RLCR loop is an amplifier — a wrong plan executed flawlessly is still wrong.

### Step 4: Run the RLCR Loop

```bash
/humanize:start-rlcr-loop docs/plan.md --codex-model gpt-5.3-codex --max 5
```

| Flag | Purpose |
|---|---|
| `--codex-model` | Codex model for reviews (e.g. `gpt-5.3-codex`) |
| `--max N` | Max iterations before auto-stop |
| `--yolo` | Full automation: skip quiz + Claude answers Codex questions |
| `--skip-quiz` | Skip the plan understanding quiz only |
| `--agent-teams` | Parallel development with Agent Teams |
| `--skip-impl` | Skip to code review (for reviewing existing changes) |

**How the loop works:** Claude implements → writes summary → Codex reviews → feedback loop until COMPLETE → `codex review` checks code quality → fix issues → done.

### One-Shot (Plan + Loop)

```bash
/humanize:gen-plan --input draft.md --output docs/plan.md --auto-start-rlcr-if-converged
```

### Monitor / Cancel

```bash
# Setup (one-time)
source ~/.claude/plugins/cache/humania/humanize/*/scripts/humanize.sh

# Monitor in another terminal
humanize monitor rlcr

# Cancel
/humanize:cancel-rlcr-loop
```

---

## Sync

```bash
cp ~/.claude/settings.json settings.json
for s in skills/*/; do
  name=$(basename "$s")
  [ -d ~/.claude/skills/"$name" ] && rsync -a --delete ~/.claude/skills/"$name"/ skills/"$name"/
done
git add -A && git commit -m "sync" && git push
```

---

## Credits

**Ten Commandments for AI-Assisted Coding** ([EN](ten_commandments_for_ai_coding.md) | [ZH](ten_commandments_for_ai_coding.zh.md)) — adapted from [Humanize](https://github.com/humania-org/humanize) by Dr. Sihao Liu, with personal extensions.
