# claude-config

Personal Claude Code configuration. Clone this repo and run two commands to fully restore on a new machine.

## Contents

| File | Purpose |
|---|---|
| `set_claude.sh` | Writes CLAUDE.md, all rule files, system_override.txt, and patches `.bashrc` with the `claude()` wrapper |
| `settings.json` | Plugin subscriptions — Claude Code auto-downloads all 38 skills on next launch |
| `skills/gen-draft/` | Custom global skill: generate high-level draft with dependency-aware execution order and observable outputs |
| `skills/gen-report/` | Custom global skill: concise experiment report |
| `skills/gen-report-detailed/` | Custom global skill: full 13-section detailed report |
| `skills/experiment-run/` | Custom global skill: config-driven experiment submission with structured output and recording |
| `skills/claude-config-sync/` | Custom global skill: sync this repo |
| `ten_commandments_for_ai_coding.md` | Methodology guide for AI-assisted coding (see [Credits](#credits)) |

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

### Step 3 — Install plugin subscriptions

```bash
cp settings.json ~/.claude/settings.json
```

Restart Claude Code. The following plugins auto-download (~38 skills total):

| Plugin | Skills |
|---|---|
| `humanize@humania` | ask-codex, humanize, humanize-gen-plan, humanize-rlcr |
| `document-skills@anthropic-agent-skills` | pdf, docx, pptx, xlsx, frontend-design, canvas-design, algorithmic-art, brand-guidelines, doc-coauthoring, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing, claude-api |
| `claude-api@anthropic-agent-skills` | same 17 skills, claude-api variant |

### Step 4 — Install custom global skills

```bash
mkdir -p ~/.claude/skills
cp -r skills/* ~/.claude/skills/
```

| Skill | Trigger |
|---|---|
| `gen-draft` | `/gen-draft`, 写draft, 生成draft |
| `gen-report` | `/gen-report` |
| `gen-report-detailed` | `/gen-report-detailed` |
| `experiment-run` | `/experiment-run`, 跑实验, 提交任务 |
| `claude-config-sync` | `/claude-config-sync`, 同步配置 |

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
