# P8 end-to-end test notes (cloud deploy on awesome-gpu-name)

Date started: 2026-05-14
Local sid: this Claude session
Remote: awesome-gpu-name (Barry@... — repo at `~/Programs/claude-config`)

## Pre-deploy state (observed)

- Local `v2` branch: 50 commits ahead of `origin/v2` — entire v2.1 work unpublished.
- Remote `~/Programs/claude-config` at `fe74c26` (pre-v2.1).
- Remote uncommitted: `content/templates/global_rules/violation.md` +49 lines (user-added W-entries, must preserve).
- Remote untracked: `skills/` 35+ dirs (user's separate skill collection, leave alone).
- Remote has v1-era artifacts present: `init_corporal.sh`, `init_soldier.sh`, `disciplinary_check.sh`, `corporal_understanding.md`, `RESEARCH_NOTES_HOOKS.md`, `.claude_status/` — candidates for cleanup but check first.

## Findings / issues / fixes during deploy

### Issue 1 — set_claude.sh dies silently after violation conflict

**Symptom**: `bash set_claude.sh` exits 0 but only deploys CLAUDE.md + memory symlink. `~/.claude/hooks/` keeps stale v1 hooks; `~/.claude/rules/` has only violation+lessons (no router, no states/, no facts_first/dispatch/recording).

**Root cause**: `set -euo pipefail` + `diff "$src" "$dst" | head -20 | sed ...`. `diff` returns 1 when files differ. pipefail propagates 1; `set -e` kills the script silently after printing the diff. Trailing `echo` lines mask the abort with exit 0.

**Fix** (set_claude.sh): wrap diff in `(diff ... || true)`. Commit: applied locally 2026-05-14.

**Impact**: This silently broke every conflict-driven re-deploy. Anyone with locally-edited violation/lessons (which is the common case after using the system) would silently get a half-deployed system. Critical bug.

### Issue 2 — repo deploys old-version W-026..W-028 entries

Remote `~/.claude/rules/violation.md` had W-026, W-027, W-028 (user-added during sessions on awesome-gpu-name). These exist only in the deployed copy, not in repo's `content/templates/global_rules/violation.md`. `yes Y` (or auto-Y after fix) overwrites them.

Backup preserved at remote `~/备份/<date>/violation.md` (full pre-deploy snapshot).

Need to merge W-026..W-028 (and any others) **back into** repo's `content/templates/global_rules/violation.md` so future deploys don't lose them.

---
