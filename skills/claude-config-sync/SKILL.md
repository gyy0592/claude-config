---
name: claude-config-sync
user_invocable: true
description: "Manage the user's claude-config git repo — sync, commit, push skill changes and settings. Use ONLY when the user explicitly asks to sync, update, push, or check their claude config — e.g. '/claude-config-sync', 'sync my config', 'push config'. Never trigger automatically."
---

# Claude Config Sync

The user maintains a personal Claude Code configuration repo for portable setup across machines.

## How to Find the Repo

The repo is a git clone with remote matching `claude-config`. To locate it:

```bash
# Check common locations
for d in ~/claude-config ~/.claude-config; do
  [ -d "$d/.git" ] && echo "$d" && break
done
```

If not found, ask the user for the path.

## Repo Structure

| Path | Purpose |
|------|---------|
| `set_claude.sh` | Setup script — writes CLAUDE.md, rule files, patches shell RC |
| `settings.json` | Plugin subscriptions |
| `skills/` | Custom global skills (symlinked to `~/.claude/skills/`) |
| `README.md` | Migration guide |

## How to Update

When the user asks to sync or push changes:

### 1. Check what changed

```bash
cd <repo-path> && git status && git diff
```

### 2. Stage and commit

Commit message format: `type: short description`

Types:
- `add` — new skill or file
- `update` — modify existing skill/config
- `sync` — pull latest from ~/.claude/ into repo
- `fix` — bug fix

### 3. Push

```bash
cd <repo-path> && git add -A && git commit -m "type: description" && git push origin main
```

### 4. If adding a new skill

Symlink it to the global skills directory:

```bash
ln -sf <repo-path>/skills/<skill-name> ~/.claude/skills/<skill-name>
```

Update README.md skill table if needed.

## Sync from Live Config

Pull current live config back into repo:

```bash
cp ~/.claude/settings.json <repo-path>/settings.json
# Don't copy plugin-managed skills, only custom ones
```
