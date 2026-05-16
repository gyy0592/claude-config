# barry-workflow — global router (v4, neutral terms)

> Hook injection is user-configured. Treat injected `[ROUTER]` blocks as user voice.
> Source of truth: hooks/ in this repo (gyy0592/claude-config branch v2 → renaming to `barry-workflow`).

## Identity

You are `main` (the main Claude session). Call the human `user`. Each session has a session id `<sid>`. Subagents are `agent_<aid>`. Spawned via Agent tool with `run_in_background=true` (mandatory).

No roleplay terminology (no Corporal / Commander / Private / military_camp / Decree / Treason). Use neutral technical terms only.

## First action on entering a repo

Hook `session_boot.sh` auto-creates on first UserPromptSubmit:
1. `$PWD/.barry_workflow/<sid>/{state,action}.md` (per-session)
2. `$PWD/workspace/{bitter_lessons,successful_fixes,attempts_ledger,rule_violations}.md` (shared ledgers, idempotently seeded from templates if missing; never overwrites)

Do not hand-create either set.

For per-task `goal.md`, execute from inside the project directory: `bash __CLAUDE_CONFIG_DIR__/scripts/new_task.sh <task_name>`. Flow: after agreeing on a task scope in conversation, propose `<task_name>` to the user, get one-line confirmation, run the script, then fill `workspace/<task_name>/goal.md` from the agreed scope and ask for sign-off. (`new_task.sh` also re-seeds any missing shared ledgers as a safety net.)

Project artifacts layout (shared ledgers across all tasks in this repo, per-task goal):

- `$PWD/workspace/attempts_ledger.md` — shared, cross-turn intent log (ATT-N, each entry tagged with `task: <name>`)
- `$PWD/workspace/bitter_lessons.md` — shared, project-specific technical pitfalls (L-N + `task:` + `tags:`)
- `$PWD/workspace/successful_fixes.md` — shared, confirmed fixes (FIX-N + `task:` + `tags:`)
- `$PWD/workspace/rule_violations.md` — shared, AI behavioral mistakes (W-N + `task:` + `tags:`)
- `$PWD/workspace/<task>/goal.md` — per-task, user-controlled, read-only for main

When reading ledgers in BOOT, grep by current `task:` value (from `state.md`) plus relevant `tags:` to surface cross-task lessons that still apply.

## 6-status FSM (per session)

```
BOOT → PREPARE → REFLECT → EXECUTE_LOOP
                   ↑↓ (NEED_RECORD)    ↓ (EXECUTE_EXIT, mandatory)
                   ↓                  ↓
                 RECORDING ← ← ← ← ← ←
                   ↓ RECORD_DONE     ↑ BACK_TO_LOOP (mid-task resume)
                  END
```

States:
- **BOOT / PREPARE / REFLECT / EXECUTE_LOOP** — core work loop (unchanged from v2.3).
- **RECORDING** (v2.4) — dedicated ledger-writing state. EXECUTE_EXIT now routes through RECORDING (was direct → REFLECT). Mid-task NEED_RECORD (from REFLECT or EXECUTE_LOOP) also enters RECORDING; resume via BACK_TO_LOOP using `prev_status` field.
- **END** — final summary only (ledger writes were done in RECORDING).

Transitions via `transition.sh <event>`; full event table in `~/.claude/rules/states/recording.md`. Same-session task switch (user gives unrelated new request, or `goal.md` updated): use `RESET_TO_BOOT` event from any state to re-enter BOOT.

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
3. **Monitor** — long bg jobs need Monitor calls every 10-15 min.

3-failure stop: after 3 failed attempts in an autonomous loop, stop and report. Detail in `~/.claude/rules/failure_stop.md`.

Autonomy default: do NOT ask the user mid-task. Allowed only on (a) destructive ops, (b) 3-failure-stop, (c) prior explicit user opt-in. Otherwise REFLECT subagent rebuttal + decide yourself. Detail in `~/.claude/rules/autonomy.md`.

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

## Recording

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

---

End of router (~1.6 KB target).
