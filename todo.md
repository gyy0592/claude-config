# TODO — Hook Injection Refactor (planned 2026-05-12)

## Background

Today's hook injection work (2026-05-12) was reverted via `git reset --hard 1cdabf6` per Commander order. The work was rushed; will redo properly based on the visualization tool output.

## Goal

Replace "AI must recite Decrees verbatim" with **hook-enforced auto-injection**, while ALSO covering scenarios where current architecture fails:

1. **CLAUDE.md not inherited by subagents** — currently Privates only see what main thread manually puts in dispatch prompt
2. **Long agent chains** (3+ hours of dispatching agents) — main thread only gets UserPromptSubmit injection ONCE at user message; thereafter no re-injection
3. **Prompt Reinforcement rule is dead** — defined in CLAUDE.md §3.5 but not injected, subagents can't see it

## Hook Coverage Plan (research-backed)

Verified hook lifecycle facts (see RESEARCH_NOTES_HOOKS.md):

| Hook | Cadence | Use For |
|------|---------|---------|
| `UserPromptSubmit` | Per turn (user msg OR cron fire) | Inject Decrees on every Commander turn + every cron iteration |
| `PostToolUse` matcher=`Agent` | After subagent returns | Re-inject Decrees in long agent chains (covers main thread degradation over hours) |
| `PreToolUse` matcher=`Agent` | Before subagent starts | Modify subagent's prompt to inject Decrees (since subagents don't read CLAUDE.md) |
| `Stop` | Per turn end | (Optional) record turn-end checks |

**NOT used**:
- `SubagentStop` — does not support additionalContext (cannot inject to parent)
- `PreToolUse` on all matchers — too frequent (30+ per turn = token waste)

## Hard Constraints

- Hook output cap: **10,000 chars** — current full Decrees + brute repeat = ~3KB, safe headroom for Prompt Reinforcement addition
- Language: **English only** in injection (Commander confirmed token-efficient)
- Format: **full Decrees verbatim** + brute repetition blocks (top + bottom) — Commander rejected slim-down

## Open Design Questions (to resolve via the HTML pipeline tool)

1. **Adaptive injection**: should hook check `transcript_path` size and inject minimal/medium/full based on stage?
   - Commander rejected this idea — wants always-full. Keep as future option only.
2. **Should Prompt Reinforcement (4-item kit) be added to injection?**
   - Yes per Commander; place as separate section, NOT as 7th Decree
3. **Should subagent injection use `PreToolUse` prompt-modification or custom subagent markdown?**
   - PreToolUse simpler — write a wrapper hook that jq-parses tool_input.prompt and prepends Decrees
4. **Codex side**: Codex has no UserPromptSubmit hook
   - Plan: keep AGENTS.md with embedded Decrees (no auto-injection possible)
   - Decision: AGENTS.md should be standalone file (not symlink) with Codex-specific tool name adaptations

## Files Affected (when this work is redone)

- NEW: `hooks/inject_decrees.sh` (UserPromptSubmit + PostToolUse)
- NEW: `hooks/inject_decrees_to_subagent.sh` (PreToolUse matcher=Agent, modifies tool_input.prompt)
- MODIFY: `content/CLAUDE.md` — remove "recite verbatim" mandates (Step 1 of 4-Step Opening, top banner, Pre-check 0, Decree 1 first-word rule). Keep all other rules.
- MODIFY: `content/AGENTS.md` — break symlink, make standalone with Codex tool names
- MODIFY: `~/.claude/settings.json` — register both hooks (idempotent merge)
- MODIFY: `set_claude.sh` — auto-deploy hooks + settings.json merge
- MODIFY: `set_codex.sh` — auto-deploy standalone AGENTS.md

## Sequence (when redoing)

1. Open `pipeline_visualization_v2.html`, walk through every pipeline, edit rule states if needed
2. Click "Export Prompt" → get a synthesized modification spec
3. Use that spec as the dispatch prompt for the implementation Private
4. Implement; test injection visible in next turn's system-reminder

## Cross-references

- `RESEARCH_NOTES_HOOKS.md` — all hook lifecycle facts + sources
- `rules_all.md` — every rule enumerated as a module
- `pipeline_visualization_v2.html` — interactive scenario walker + export prompt
