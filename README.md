 [🇨🇳 中文版](README.zh.md)

# Barry's Workflow v2 — a state-controller for Claude Code

> Repo name `claude-config` is legacy. The project itself is **Barry's Workflow v2** — `v2` because v1 was the earlier military-cosplay rule set; this rewrite is a clean, state-machine-based redesign.

> **What it is**: a finite state machine that constrains what Claude (the AI) is allowed to do at any moment, plus a structured patch system that lets the machine evolve as you (or it) discover where the defaults fall short. **Not** a prompt collection. **Not** a wrapper. A behaviour controller.

> **For others / first-time readers**: [`docs/big_picture.html`](docs/big_picture.html) — motivation, entropy collapse, the two solution principles. No implementation jargon.
> **For engineers**: [`docs/implementation.html`](docs/implementation.html) — zero-prereq tour of every file, why each exists, honest verdict on whether it works.

## Why

LLM coding sessions fail in predictable ways: skipping checks, claiming "done" before running tests, polling forever, losing context across restarts. v4 fixes these by **constraining state, not generating better prompts**.

## Big picture

```
                              ┌─────────────────────────┐
                              │     FSM skeleton        │  ← invariant
                              │  BOOT → PREPARE →       │
                              │  REFLECT ↔ EXECUTE_LOOP │
                              │  → END                  │
                              └─────────────────────────┘
                                          ▲
                                          │ enforced by hooks
                              ┌───────────┴─────────────┐
                              │   seed rules            │  ← initial best-guess
                              │  ~/.claude/rules/*.md   │     (replaceable)
                              └───────────┬─────────────┘
                                          ▲
                                          │ overrides
                              ┌───────────┴─────────────┐
                              │   patches/ (planned)    │  ← grows over time
                              │  human-written OR       │     human-curated
                              │  auto-extracted from    │     auto-drafted
                              │  bitter_lessons.md      │
                              └─────────────────────────┘
```

- **FSM skeleton** (`content/rules/fsm.md`): the 6-state controller. Doesn't change.
- **Seed rules** (`content/rules/*.md`): 10 policy files covering identity, dispatch, recording, REFLECT rebuttal, FSM details, Codex adapter, etc. Initial defaults; can be overridden by patches.
- **Patches** (planned, v4.1): structured deltas that augment or override seed rules per scenario. Two sources — human-written when you spot a gap, auto-drafted by AI when it ships a fix.

Read in order:

1. [`big_picture.md`](docs/big_picture.md) — design essence + patch system + self-evolution. **Start here.**
2. [`fsm_visualization.html`](docs/fsm_visualization.html) — click-through diagram of the 6 states, with each state's expected sub-flow and predicted failure modes. Light theme.
3. [`scenarios.html`](docs/scenarios.html) — 5 concrete scenarios (long-monitor, code-bug, perf-bug, simple, exploratory) with state-by-state expected behaviour + common pitfalls.
4. [`v4_plan.md`](docs/v4_plan.md) — the original implementation plan (P1–P10).
5. [`RESEARCH_NOTES_GOAL_HOOK.md`](docs/RESEARCH_NOTES_GOAL_HOOK.md) — why `/goal` replaces stop hooks.

## Current status (2026-05-14)

| P | Task | Status |
|---|---|---|
| P1 | de-cosplay + neutral terminology | ✅ |
| P2 | rules split + slim router inject (1166 B) | ✅ |
| P3 | state file template + BOOT hook + transition.sh | ✅ |
| P4 | PREPARE helper (cache_hit_map + 4-element check) | ✅ |
| P5 | EXECUTE_LOOP discipline + audit (regex expanded post-rebuttal) | ✅ |
| P6 | REFLECT rebuttal protocol (SendMessage-driven) — live-tested 2 rounds | ✅ |
| P7 | PreToolUse short-nudge hook (≤100 char, non-blocking) | ✅ |
| P8 | Demo task end-to-end (Qwen-0.5B + GSM8K + activation hook) | ⏸ awaiting user supervision |
| P9 | `/goal` supersedes stop_self_audit.sh | ✅ |
| P10 | Codex adapter (tool mapping + SendMessage poll fallback) | ✅ |
| — | `patches/` system (v4.1) | ❌ not started |

**Active hooks** (`~/.claude/settings.json`):
- `UserPromptSubmit` → `inject_router.sh` + `session_boot.sh`
- `PreToolUse` → `pretooluse_short_nudge.sh`
- `PostToolUse:Bash` → bg-log

Legacy `inject_decrees.sh` / `stop_self_audit.sh` / `reset_session_status.sh` are on disk but **unregistered** (kept for git history).

## Concrete real-world cost (measured this session)

| Operation | Time | Tokens |
|---|---|---|
| REFLECT rebuttal — round 1 | 11 min 21 s | ~55 k (agent-side) |
| REFLECT rebuttal — round 2 (push back) | 48 s | +6.6 k |
| Total rebuttal cost | 12.1 min | ~61.5 k (agent), ~3-5 k (main) |

→ Worth it for design decisions / complex plans. Skip for trivial edits (see scenario 3 in `scenarios.html`).

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
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex

# For humanize plugin, see section below for clean installation
```

#### Humanize Plugin Management

**Clean old installations:**
```bash
# Inside Claude Code - remove old humanize installations
/plugin uninstall humanize@humania  # if exists
/plugin uninstall humanize@PolyArch  # if exists
/plugin marketplace remove humania   # if exists
```

**Install from local git repo:**
```bash
# 1. Clone/update your fork
git clone https://github.com/gyy0592/humanize.git ~/Programs/humanize
cd ~/Programs/humanize && git checkout claude-latest

# 2. Install in Claude Code
/plugin marketplace add ~/Programs/humanize
/plugin install humanize@PolyArch
/reload-plugins
```

**Update workflow:**
```bash
cd ~/Programs/humanize
git fetch upstream dev
git rebase upstream/dev  # keeps Claude features + latest upstream
git push origin claude-latest --force-with-lease
# Reinstall in Claude Code if needed
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
