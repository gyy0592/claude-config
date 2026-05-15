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

## Cloud claude e2e run (cwd=/home/Barry/github_repo/LLM_sampling_implement)

Invocation: `claude --dangerously-skip-permissions --output-format stream-json --verbose --max-turns 60 -p "<migration prompt>"`. Prompt told it to walk the FSM, build 5 ledgers in `workspace/v5_mini_pipeline/`, archive `militar_camp/` etc. into `legacy_v1_<date>/`, and write [PLAN]/[OBSERVE] to action.md. Session id: `b68e44cd-2a6d-49f0-b80d-577a157678ee`.

### 4-check observation

| check | result | evidence |
|---|---|---|
| FSM transitions (state.md `current_status` cycles through BOOT→PREPARE→REFLECT→EXECUTE_LOOP, `stage_history` non-empty) | **PASS** | 5 entries in `stage_history` (BOOT_DONE 07:19:46 → PREPARE_DONE 07:20:22 → REFLECT_DONE 07:22:40 → EXECUTE_EXIT 07:32:01 → REFLECT_DONE 07:33:32). All 4 transition.sh events fired by cloud claude. *(Note: this test ran under v2.3; in v2.4 EXECUTE_EXIT → RECORDING, not REFLECT)* |
| router injection (each turn has `[ROUTER · state=X]`) | **PASS** | Confirmed via extracted JSONL: 3+ ROUTER occurrences in stream; per-state router file `router_<STATE>.md` swapped automatically as state.md advanced. |
| subagent dispatch works (`Agent(run_in_background=true)`) | **PASS** | 2 Agent dispatches observed in transcript: id=1sVjs9Ux (pre-task REFLECT rebuttal, 5 questions) + id=SQTZRL33 (EXECUTE: create 5 ledger files). Both went out fine. |
| session_boot creates `.barry_workflow/<sid>/{state,action}.md` | **PASS** | On first UserPromptSubmit in this repo (which has `CLAUDE.md` at root), `session_boot.sh` auto-created `.barry_workflow/b68e44cd-…/{state,action}.md` from templates with YAML preamble + sid + created_at. |

### Deliverables produced by cloud claude (correctness)

- `workspace/v5_mini_pipeline/` — all 5 ledgers present: attempts_ledger.md, bitter_lessons.md, goal.md, rule_violations.md, successful_fixes.md.
- `legacy_v1_20260514/` — created; old `militar_camp/`, `militar_camp_v1_legacy/`, `.claude_status/`, `bitterlesson.md` all moved into it (verified: those paths no longer exist at repo root).
- (TODO when watcher fires: spot-check ledger content for L-N/W-N/FIX-N/ATT-N + tags schema, verify [PLAN]/[OBSERVE] really got written to action.md.)

### Issue 3 — `stage_history` entries are prepended, not appended

`hooks/transition.sh` mutator block replaces the `stage_history:` line with a fresh `stage_history:` + new entry, before any pre-existing `  - {...}` rows get re-emitted by the else branch. Result: newest entry is on top, oldest at the bottom — reverse chronological. Cosmetic only; consumers (audit greps, eyeball reading) keep working. Suggested fix: change the mutator to append by detecting the `stage_history:` block end and inserting before the next top-level key. Low priority — but worth noting because the obvious mental model is "append".

### Issue 4 — /goal stop hook fires even when bg tasks pending (Claude Code design)

Investigated the bundled `claude.exe` binary (haiku agent). Finding: `u9H` evaluator (the prompt-judge) is invoked unconditionally at the end of every assistant turn while a goal is active. The code DOES track `backgroundTaskId` and `in_progress_tool_use_ids`, but does NOT guard the stop-hook call on them. There is no config flag / env var to skip eval while bg tasks run. So when this local claude session has a bg watcher polling cloud claude pid, the user's /goal stop hook still fires after every turn — costing tokens on each round-trip until the bg task fires.

This is upstream Claude Code behavior; not in our repo's scope to fix. Workaround: use long foreground tool calls to keep turns open (but the harness blocks leading-sleep patterns).

### Open follow-ups

- Wait for cloud claude process to fully exit (watcher `bvkxxl42h` will fire) → inspect its final assistant summary + diff what got committed.
- Spot-check ledger content: do L-N entries have tags? Do FIX-N entries have proper formatting?
- Inspect `action.md` for [PLAN]/[OBSERVE] discipline — does cloud claude actually use them per tool call, or did it skip?
- Confirm no `git rm` happened — only `mv` to legacy_v1_ archive (per (d) constraint).
- Sonnet agent `ad09b79e0fd4b03e1` is adding transition logging (P30) — review before commit/push.
- Do NOT push these notes yet; user requested review before publishing.

---
