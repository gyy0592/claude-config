---
name: claude-config-sync
description: "Manage the user's claude-config repo (github.com/gyy0592/claude-config.git). Use ONLY when the user explicitly asks to sync, update, push, or check their claude config — e.g. '/claude-config-sync', '同步claude配置', 'push我的config', '更新claude-config'. Never trigger automatically."
---

# Claude Config Sync

The user maintains a personal Claude Code configuration repo that makes it easy to restore their full Claude setup on any new machine.

## Repo Location

```
/home/barry/claude-config
```

Remote: `git@github.com:gyy0592/claude-config.git` (branch: main)

## What's In It

| Path | What |
|------|------|
| `set_claude.sh` | Setup script — writes CLAUDE.md, rule files, system_override.txt, patches .bashrc |
| `settings.json` | Plugin subscriptions (auto-downloads ~38 skills on launch) |
| `skills/` | Custom global skills (symlinked to `~/.claude/skills/`) |
| `README.md` | Migration guide |

## Current Custom Skills

| Skill | Directory | Trigger |
|-------|-----------|---------|
| gen-report | `skills/gen-report/` | `/gen-report` |
| gen-report-detailed | `skills/gen-report-detailed/` | `/gen-report-detailed` |
| experiment-run | `skills/experiment-run/` | `/experiment-run`, 跑实验, 提交任务 |
| claude-config-sync | `skills/claude-config-sync/` | `/claude-config-sync` |

## How to Update

When the user asks to sync or push changes:

### 1. Check what changed

```bash
cd /home/barry/claude-config && git status && git diff
```

### 2. Stage and commit

Commit message format: `type: short description`

Types:
- `add` — new skill or file
- `update` — modify existing skill/config
- `sync` — pull latest from ~/.claude/ into repo
- `fix` — bug fix

Examples:
```
add: experiment-run skill
update: gen-report skill with new template
sync: settings.json and rules from ~/.claude
fix: set_claude.sh bashrc path
```

### 3. Push

```bash
cd /home/barry/claude-config && git add -A && git commit -m "type: description" && git push origin main
```

### 4. If adding a new skill

Also symlink it to the global skills directory:

```bash
ln -sf /home/barry/claude-config/skills/<skill-name> /home/barry/.claude/skills/<skill-name>
```

And update the README.md table if needed.

## Sync from Live Config

If the user wants to pull their current live config back into the repo:

```bash
cp ~/.claude/settings.json /home/barry/claude-config/settings.json
# Don't copy plugin-managed skills, only custom ones
```
