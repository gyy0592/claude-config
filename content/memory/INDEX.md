# content/memory/ Index (Read on demand, not always resident)

This directory holds workflow / dispatch / silence details that are "read on demand, not auto-injected every turn".

In v2-hook-era: Decrees + Iron Rules + Prompt Reinforcement are auto-injected via hooks (`hooks/inject_decrees.sh` + `inject_decrees_to_subagent.sh`). The slim CLAUDE.md routes to these `memory/` files on demand.

**Global rules** (W-XXX violations, L-XXX lessons) have MOVED to `~/.claude/rules/` and are auto-loaded by Claude every session — no longer in `content/memory/` for active reading (deprecated copies retained 1 release cycle for backward compat).

## v2 File Trigger Table

| File | Scope | Description | Trigger Read Condition |
|------|-------|-------------|------------------------|
| `~/.claude/rules/violation.md` | GLOBAL (auto-loaded) | AI rule violations (W-XXX + tags) | Suspecting red line / Commander flagging violation / before writing W-XXX. Already in context after auto-load — Read once to confirm. |
| `~/.claude/rules/lessons.md` | GLOBAL (auto-loaded) | Cross-project AI behavior wisdom (L-XXX + tags) | Before writing comprehensive reflection; citing past "correct practices"; `tags:` grep at session start |
| `content/memory/workflows.md` | PROJECT-RELATIVE on-demand | 4-step workflow + long-task monitoring + debugging + entry formats + retest 3-Qs (v2) + INFERENCE evidence rules (v2) | Writing/running code; starting long tasks; debugging; listing indicators; writing [OBSERVE]/[REFLECT]; 3-step fix-loop |
| `content/memory/soldier_protocol.md` | PROJECT-RELATIVE on-demand | Dispatch templates + Iron Rules A-G (also auto-injected by PreToolUse:Agent hook) + silence format + question checklist | Before dispatching; before filling soldier_status.md authorization; before AskUserQuestion; reference for Iron Rule details |
| `militar_camp/operation_log.md` | PROJECT | Every meaningful operation | Hands-on tasks; before/after edits |
| `militar_camp/attempts_ledger.md` | PROJECT | Bug-fix / improvement attempts | Each attempt at fixing X / improving Y |
| `militar_camp/bitter_lessons.md` | PROJECT | Failed efforts archive (WRONG WAY N) | After a failed attempt is abandoned; review before re-trying anything similar |
| `militar_camp/successful_fixes.md` | PROJECT | Final winning fixes (FIX N) | After confirmed stable fix; reference when similar bug recurs |

## Deprecated locations (1 release cycle, do not write new entries)

- `content/memory/violations.md` → see `~/.claude/rules/violation.md`
- `content/memory/lessons.md` → see `~/.claude/rules/lessons.md`
- `militar_camp/warning_board.md` → not created in v2; functionality split into global `violation.md` + project `bitter_lessons.md`
- `militar_camp/reward_board.md` → not created in v2; functionality moved to `successful_fixes.md`
- `militar_camp/traitor.md` → not created in v2; functionality merged into global `violation.md`

## Don't know which to read → grep tags

`grep -lE "tags:.*<tag>" ~/.claude/rules/*.md content/memory/*.md militar_camp/*.md`

Common tags: `scope-creep` / `over-design` / `language-violation` / `concept-confusion` / `flow-skip` / `memory-blind` / `fatigue` / `dead-link` / `plan-gap` / `listen-comprehension` / `premature-answer` / `codex-overtrust` / `cuda-oom` / `memory-leak` / `dataloader`.

## Mandatory Closing for Action Tasks (one of two)

(a) Append new entry to relevant ledger file (`operation_log.md` / `attempts_ledger.md` / `bitter_lessons.md` / `successful_fixes.md` / `~/.claude/rules/violation.md` / `~/.claude/rules/lessons.md`) with `tags:` where applicable
(b) Explicitly write `[no new ledger entries this turn]` in corporal_action.md

Missing both = Dereliction of Duty precursor.
