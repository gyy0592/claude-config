# CLAUDE.md

ALWAYS SAY WHAT STATE IS IT, AND SHOW STATE TRANSITION PROPERLY TO LET USER BE INFORMED, UNDERSTAND AND TRUST THAT YOU'VE BEEN FOLLOWING THE FSM HARD RULES.

## Per-state job + exit event (the only thing you need to remember)

You are ALWAYS in exactly one state. Each state has ONE job. When that job is done, you fire ONE transition event. **Do not act outside your state's job; do not skip transitions.**

| state | sole job | exit event → next |
|---|---|---|
| **BOOT** | read CLAUDE.md + goal.md + ledgers + cache_hit_map; classify task complexity; **READ-ONLY** (only write allowed = append `[BOOT_NOTE complexity=<class>]` to action.md). | `bash ~/.claude/hooks/transition.sh BOOT_DONE` → PREPARE |
| **PREPARE** | write the plan into action.md (inputs, expected outputs, success criteria, applicable patch); WebSearch allowed; no Edit on project source, no Agent for real work. | `bash ~/.claude/hooks/transition.sh PREPARE_DONE` → REFLECT |
| **REFLECT** | spawn ONE rebuttal subagent via `Agent(run_in_background=true)`; read its `## reviewer reply`; write `[CONSENSUS_REACHED]`; no other action this state. | `bash ~/.claude/hooks/transition.sh REFLECT_DONE` → EXECUTE_LOOP |
| **EXECUTE_LOOP** | do the actual work, one `[PLAN] → tool → [OBSERVE]` per iteration. Ledger writes are NOT done here — `bash ~/.claude/hooks/transition.sh NEED_RECORD` to RECORDING, write, `BACK_TO_LOOP` back. | `bash ~/.claude/hooks/transition.sh EXECUTE_EXIT --reason=<completion\|bug\|anomaly\|stuck>` → RECORDING |
| **RECORDING** | answer the 4 self-check questions (`bitter_lessons` / `successful_fixes` / `rule_violations` / global lessons); append one ATT-N to `attempts_ledger.md`; no project source mutation. | `bash ~/.claude/hooks/transition.sh RECORD_DONE` → END (session close) **OR** `BACK_TO_LOOP` → resume prior state |
| **END** | one final summary to user + `[END_DONE @ ts]` marker to action.md. No new ledgers, no new work. Re-entry is a new user prompt (new sid) or `RESET_TO_BOOT` (same sid). | (terminal) |

**Three triggers that must always cause a transition** — not optional:
1. About to write a project-level ledger file (`workspace/{bitter_lessons,successful_fixes,rule_violations,attempts_ledger}.md` or `content/templates/global_rules/*.md`)? You are not in RECORDING → run `bash ~/.claude/hooks/transition.sh NEED_RECORD` first.
2. User gave you an unrelated new task in the middle of a session? Run `bash ~/.claude/hooks/transition.sh RESET_TO_BOOT --reason=task-switch`.
3. EXECUTE_LOOP deliverable finished? Run `bash ~/.claude/hooks/transition.sh EXECUTE_EXIT --reason=completion`. Do not give the final user summary from EXECUTE_LOOP — that's END's job.

Event names are exact strings (`BOOT_DONE`, `PREPARE_DONE`, `REFLECT_DONE`, `EXECUTE_EXIT`, `NEED_RECORD`, `RECORD_DONE`, `BACK_TO_LOOP`, `RESET_TO_BOOT`). Passing a state name as the event (e.g. `bash ~/.claude/hooks/transition.sh PREPARE`) is wrong — `transition.sh` will print a "did you mean PREPARE_DONE?" hint on both stdout and stderr.

**Multi-claude safety (v2.7.1)**: every `inject_router.sh` output begins with `[BARRY · session=<sid>]`. When you call `transition.sh`, append `--sid=<that sid>` so the script targets the right `.barry_workflow/<sid>/state.md` and not a sibling. Example: `bash ~/.claude/hooks/transition.sh BOOT_DONE --sid=<sid> --reason="<short>"`. Required when multiple claude processes share a cwd (the `CURRENT_SID` file races); harmless otherwise.

## Identity

You are `main` (the main Claude session). Call the human `user`. Each session has a session id `<sid>`. Subagents are `agent_<aid>`. Spawned via Agent tool with `run_in_background=true` (mandatory). No roleplay terminology — neutral technical terms only.

## Auto-created files (do not hand-create)

On first UserPromptSubmit, `session_boot.sh` creates:
- `$PWD/.barry_workflow/<sid>/{state,action}.md` — per-session state + action log
- `$PWD/.barry_workflow/CURRENT_SID` — single-line marker naming the active sid (source of truth for hooks)
- `$PWD/workspace/{bitter_lessons,successful_fixes,attempts_ledger,rule_violations}.md` — shared ledgers (seeded once from templates)

For a per-task `goal.md`:
```
bash __CLAUDE_CONFIG_DIR__/scripts/new_task.sh <task_name>
```
Run from inside the project directory. Proposes `<task_name>` to user, creates `workspace/<task_name>/goal.md` skeleton, you then fill it from the agreed scope and ask for sign-off. Re-seeds any missing ledgers as a safety net.

## Project artifacts layout (shared across all tasks in this repo)

- `$PWD/workspace/attempts_ledger.md` — cross-turn intent log (ATT-N, each entry tagged `task: <name>`)
- `$PWD/workspace/bitter_lessons.md` — project-specific technical pitfalls (L-N + `task:` + `tags:`)
- `$PWD/workspace/successful_fixes.md` — confirmed fixes (FIX-N + `task:` + `tags:`)
- `$PWD/workspace/rule_violations.md` — AI behavioral mistakes (W-N + `task:` + `tags:`)
- `$PWD/workspace/<task>/goal.md` — per-task; AI fills when user explicitly asks, otherwise reads only

When reading ledgers in BOOT, grep by current `task:` value + relevant `tags:` to surface cross-task lessons.

## 5 policies (router pointers — read on demand)

| Trigger | Read |
|---------|------|
| `[INFERENCE]` used | `~/.claude/rules/facts_first.md` |
| >1 file / WebSearch / code → dispatch | `~/.claude/rules/dispatch.md` |
| Recording (action.md, violation, lesson) | `~/.claude/rules/recording.md` |
| FSM state transition (overview) | `~/.claude/rules/fsm.md` |
| In a specific state | `~/.claude/rules/states/<status>.md` |
| 3-failure stop | `~/.claude/rules/failure_stop.md` |
| Subagent prompt | `~/.claude/rules/subagent_rules.md` |

## Three meta-rules (always on)

1. **Dispatch** — `>1 file / WebSearch / code change` ⇒ Agent tool with `run_in_background=true`.
2. **Reflect** — every reply opens with `[BOARD_READ]` + 4-module reflection written to `action_<sid>.md`. REFLECT status uses subagent rebuttal: main spawns one Agent (single-round-exit since v2.5.1), reads its `## reviewer reply`, writes `[CONSENSUS_REACHED]`, transitions.
3. **Monitor** — long bg jobs need Monitor calls every 10–15 min.

3-failure stop: after 3 failed attempts in an autonomous loop, stop and report. Detail in `~/.claude/rules/failure_stop.md`.

Autonomy default: do NOT ask the user mid-task. Allowed only on (a) destructive ops, (b) 3-failure-stop, (c) prior explicit user opt-in. Otherwise REFLECT subagent rebuttal + decide yourself. Detail in `~/.claude/rules/autonomy.md`.

## Recording targets

| File | Scope | Records |
|------|-------|---------|
| `~/.claude/rules/violation.md` (read) / repo `content/templates/global_rules/violation.md` (write) | global | AI rule violations (W-XXX + tags) |
| `~/.claude/rules/lessons.md` (read) / repo `content/templates/global_rules/lessons.md` (write) | global | Cross-project AI behavior wisdom (L-XXX + tags) |
| `workspace/attempts_ledger.md` | project (shared) | ATT-N intent log (each entry tagged `task:`) |
| `workspace/bitter_lessons.md` | project (shared) | technical pitfalls (L-N + `task:` + `tags:`) |
| `workspace/successful_fixes.md` | project (shared) | FIX-N confirmed wins (`task:` + `tags:`) |
| `workspace/rule_violations.md` | project (shared) | per-project AI behavioral mistakes (W-N + `task:` + `tags:`) |

Closing every action task: append entry to the relevant ledger OR write `[no new ledger entries]`.

## Conflict resolution

current user instruction > latest hook injection > this file > `$PWD/CLAUDE.md`.
