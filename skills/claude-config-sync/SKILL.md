---
name: claude-config-sync
user_invocable: true
description: "Manage the user's claude-config git repo — sync, commit, push skill changes and settings. Use ONLY when the user explicitly asks to sync, update, push, or check their claude config — e.g. '/claude-config-sync', 'sync my config', 'push config'. Never trigger automatically."
---

# Claude Config Sync

The user maintains a personal Claude Code configuration repo for portable setup across machines.

## How to Find the Repo

```bash
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
| `README.md` | Migration guide + skill table + credits |

---

## Step 1 — Detect Symlink vs Copy State

Before syncing, determine which skills in `~/.claude/skills/` are symlinks pointing to the repo and which are standalone copies:

```bash
ls -la ~/.claude/skills/ | grep "^l"   # symlinks — already in sync, no copy needed
ls -la ~/.claude/skills/ | grep -v "^l" | grep "^d"  # directories — may need syncing
```

- **Symlinks**: changes are already reflected in the repo. No action needed.
- **Standalone copies**: diff against repo version. If different, copy into repo.
- **New skills** (in live but not in repo): copy into repo, then symlink live → repo.

## Step 2 — Clean Up Residuals

Remove artifacts that must not be committed:

```bash
# Remove skill-creator eval workspace residuals
rm -rf <repo-path>/skills/*-workspace/

# Remove any __pycache__, .DS_Store, etc.
find <repo-path> -name '__pycache__' -o -name '.DS_Store' -o -name '*.pyc' | xargs rm -rf
```

## Step 3 — Security Scan (HARD BLOCK — must pass before any commit)

Scan ALL staged changes for sensitive information. If ANY match is found, STOP and warn the user — do NOT commit.

```bash
# Scan the diff for secrets (note: sk- keys can contain hyphens, e.g. sk-or-v1-abc123...)
cd <repo-path>
SECRET_PATTERN='(sk-[a-zA-Z0-9_-]{20,}|api_key\s*[:=]\s*"?[a-zA-Z0-9_-]{10,}|password\s*[:=]|secret\s*[:=]|Bearer [a-zA-Z0-9_-]{10,}|AAGHW|Jxn2)'

# Scan staged diff
git diff HEAD --staged -- . | grep -iE "$SECRET_PATTERN" \
  && echo "BLOCKED: sensitive info detected in diff" || echo "diff CLEAN"

# Scan new untracked files about to be added
for f in $(git ls-files --others --exclude-standard); do
  grep -iE "$SECRET_PATTERN" "$f" 2>/dev/null \
    && echo "BLOCKED: sensitive info in $f"
done
```

Placeholder patterns like `<key from user>` or `<endpoint URL>` are safe — only flag actual credential values.

## Step 4 — README Skill Table Check (HARD BLOCK before commit)

If any skill was added or removed, the README.md skill table MUST be updated in the same commit. Check BEFORE staging:

```bash
# List all skill dirs in repo
ls -d <repo-path>/skills/*/

# Compare against README skill table — any missing or stale entries?
grep -c '<skill-name>' <repo-path>/README.md
```

If the README is stale (new skill not listed, or removed skill still listed), update it NOW — do NOT commit without a correct README.

## Step 5 — Show Change Summary for User Confirmation

Before committing, display a summary and wait for user approval:

```
═══════════════════════════════════════════
  Config Sync — Change Summary
═══════════════════════════════════════════

  Modified:
    - skills/gen-draft/SKILL.md  (+62 -1)
    - README.md                  (+11 -0)

  New files:
    - ten_commandments.md

  Deleted:
    - (none)

  Security scan: CLEAN
  README skill table: UP TO DATE

  Proceed? (user must confirm)
═══════════════════════════════════════════
```

Do NOT proceed to commit/push until the user explicitly confirms.

## Step 6 — Stage, Commit, Push

```bash
cd <repo-path>
git add <specific files>   # prefer named files over -A
git commit -m "type: short description"
git push origin main
```

Commit message format: `type: short description`

Types:
- `add` — new skill or file
- `update` — modify existing skill/config
- `sync` — pull latest from ~/.claude/ into repo
- `fix` — bug fix

## Step 7 — Post-Commit: Symlink Verification

After committing, verify symlinks:

Any new skill added to the repo must be symlinked to the live config:

```bash
ln -sf <repo-path>/skills/<skill-name> ~/.claude/skills/<skill-name>
```

Any skill that exists as a standalone copy in `~/.claude/skills/` but is identical to the repo version should be converted to a symlink to prevent future drift.

---

## Sync from Live Config (reverse direction)

When pulling live config back into repo:

```bash
cp ~/.claude/settings.json <repo-path>/settings.json
# Only copy custom skills (not plugin-managed ones)
# Plugin skills live under ~/.claude/skills/<plugin-name>:<skill-name> — skip these
```
