# Plan: merge Barry's Workflow v2 (Claude) to main

History context: the v2 branch grew a lot of cruft from earlier explorations (v1 cosplay artifacts, codex side-line, telegram notification scripts, humanize/jw plugin glue, old visualization iterations, planning markdown files). For the **main** branch we want a clean release of ONLY what's needed to deploy and use Barry's Workflow v2 (Claude). Codex / humanize / telegram / jw / old plans all stay on the v2 branch (preserved for history) but don't ship to main.

Release name: **Barry's Workflow v2 — Claude Code Edition**.
Tag suggestion: `bw-v2-claude-1.0`.

---

## Strategy

1. From current `v2` HEAD, branch off:  `git checkout -b barry-workflow-v2-claude`
2. In this branch, `git rm` everything in the 🔴 DROP list below.
3. Edit `set_claude.sh` to drop references to removed files (already partially done in P29, but double-check).
4. Update README cross-links if they pointed to removed docs.
5. Commit ONE squash-style commit: `Barry's Workflow v2 — Claude Code Edition (initial release)`.
6. Merge into `main` (fast-forward or PR — user decides).
7. Tag `bw-v2-claude-1.0`.
8. **Do not delete `v2` branch** — keep it for codex/humanize/jw work and any v2.2 development.

---

## 🟢 KEEP — ships to main

### Root
- `README.md` (new EN, written 2026-05-14, references `bp_*_en.png`)
- `README.zh.md` (new CN, references `bp_*.png`)
- `CLAUDE.md` (project-level)
- `set_claude.sh` (deploy script, cleaned in P29)
- `cleanup_v1.sh` (v1 residual cleanup)
- `.gitignore` (already excludes `.barry_workflow/`, etc.)

### `hooks/` — all 8 files
- `_session_lib.sh`
- `execute_loop_audit.sh`
- `inject_router.sh`
- `prepare_helper.sh`
- `pretooluse_short_nudge.sh`
- `session_boot.sh`
- `state_enforce.sh`
- `transition.sh`

### `scripts/` — all 4 files
- `extract_transcript.py` — clean transcript dumper
- `switch_hooks.sh` — toggle hooks on/off
- `_transition_log_helper.py` — P30 transition logger
- `build_viewer_manifest.py` — viewer data builder

### `content/`
- `content/CLAUDE.md`
- `content/rules/` — all router/states/patches/messages + workflow_config.yaml
- `content/templates/` — all state/action/reflection/ledger templates + `global_rules/violation.md` + `lessons.md`

### `skills/` — keep the entire directory (35+ skills)
User explicitly said: "skills这些当然也是要的 要把全新的skill和skill的文档都移动过去"

### `docs/` — keep these only
- `big_picture.html` + `big_picture.md` (CN)
- `big_picture_en.html` (EN)
- `implementation.html`
- `scenarios.html`
- `problem_discussion.md` + `problem_discussion.html`
- `p8_e2e_notes.md` (P8 demo report)
- `pros_cons.md`
- `skills.md` + `skills.zh.md` (skill catalog)
- `v2.2_plan.md` (forward-looking)
- `img/` — all `bp_*.png` (CN + `_en` variants) + `bp_full.png` + `bp_full_en.png`

### `viewer/` — keep entire dir (built by P-viewer agent)
- `index.html`, `viewer.css`, `viewer.js`
- `lib/marked.min.js`
- `data/` (sample P8 session data)
- `data/index.json`

---

## 🔴 DROP — do NOT ship to main

### Root — planning / legacy docs
- `v2_plan.md` — v1-era plan, superseded
- `todo.md` — stale
- `workflow_spec.md` — old spec
- `truthfulness_protocol_prompt.md` — v1 prompt fragment
- `draft.md`, `humanize_analysis.md`, `paper_reader.md` — unrelated work-in-progress notes
- `README.en.legacy.bak` — backup of the old EN README that mentioned humanize/codex/RLCR (kept on v2 branch for reference; not for main)

### Root — codex side
- `set_codex.sh`
- `setup_codex.sh`
- `codex_info.yaml.template`

### Root — legacy utility scripts
- `set_monitor_time.sh` (v1 monitor interval tweaker)
- `set_tg.sh` (telegram notification, unrelated)
- `make_release.sh` (legacy release helper)
- `test_cross_platform.sh` (old test)
- `jw-capture-session.sh`, `start-jw.sh`, `stop-jw.sh` (jw = humanize "纪委" hook from v1)

### Root — top-level `settings.json`
- The repo had a `settings.json` at root that was an old example deployment. The new `set_claude.sh` writes `~/.claude/settings.json` from scratch via Python merge logic. The root one is misleading. Drop.

### `docs/` — old plan / visualization
- `v2.1_plan.md` — historical plan, superseded by current state
- `v3_plan.md` — never executed
- `v4_plan.md` — superseded by v2.1 actual work
- `fsm_visualization.html` — earlier iteration of state-machine viz, replaced by `scenarios.html` + `big_picture.html`
- `pipeline_visualization_v4.html` — earlier iteration, same replacement
- `RESEARCH_NOTES_GOAL_HOOK.md` — research notes on Claude Code internals (interesting but not ship-relevant; keep in v2 branch as reference)

### `patches/` (root-level) — humanize-specific
- `patches/fix-humanize-openrouter-model.sh`
- `patches/fix-humanize-session-id.sh`
- (Note: `content/rules/patches/` is the v2 scenario patches — that one we KEEP.)

### Runtime / cruft
- `.barry_workflow_temp/` — temp dir from an exploration session, never tracked properly
- `.claude_status/` — v1 runtime residual

---

## 🟡 Edge cases — decide before merge

- `docs/RESEARCH_NOTES_GOAL_HOOK.md` — useful technical notes on /goal stop hook investigation (from haiku probe). **Recommendation: KEEP** since it documents an important Claude Code design constraint we hit. Move it from "drop" to "keep" if you want.
- Old `content/templates/*.md` cosplay templates — already cleaned in P18; nothing to do, just verify with `ls content/templates/`.

---

## Pre-merge checklist

- [ ] Audit `set_claude.sh` for any leftover refs to dropped files. (P29 already cleaned most; verify nothing in the deploy script touches `set_tg.sh`, `init_corporal.sh`, etc.)
- [ ] Audit `README.md` + `README.zh.md` for broken links to dropped docs.
- [ ] Verify `viewer/` works after a clean checkout (run `python3 -m http.server 8765` inside `viewer/`).
- [ ] Run `bash set_claude.sh` on a fresh machine (or fresh `~/.claude/`) to confirm full deploy works end-to-end.
- [ ] Tag commit, write release notes (link to `docs/p8_e2e_notes.md` as the proof-of-work).

---

## Open question

User also wants to remove the **`~/.claude/memory`** symlink line from `set_claude.sh` (it points to `content/memory/`, which is a v1 leftover, not used by Claude Code — confirmed by haiku probe `aa9a19276d45da867`). This belongs in the merge prep: drop the symlink + drop the `content/memory/` dir. Add to drop list before merging.

---

## Order of operations

1. Finish v2.1+ outstanding fixes if any (none currently blocking).
2. Optional: do v2.2 P31 (subagent FSM) + P35 (yaml runtime) first on the v2 branch, so main gets them too. **Or** ship current state to main now and pull v2.2 in later.  **Recommendation: ship now, v2.2 follows as a 1.1 release.**
3. Cut `barry-workflow-v2-claude` branch from v2 HEAD.
4. Apply DROP list via `git rm`.
5. Final review.
6. Merge to main.
7. Tag.
