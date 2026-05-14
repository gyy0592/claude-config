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

## 4-status FSM (per session)

```
BOOT → PREPARE → REFLECT → EXECUTE_LOOP
                   ↑              ↓ (anomaly / completion)
                   └──────────────┘
```

Transitions via `transition.sh <event>`; details in `~/.claude/rules/fsm.md`. Same-session task switch (user gives unrelated new request, or `goal.md` updated): use `RESET_TO_BOOT` event to re-enter BOOT and re-read inputs.

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
2. **Reflect** — every reply opens with `[BOARD_READ]` + 4-module reflection written to `action_<sid>.md`. REFLECT status uses subagent rebuttal (main drives via SendMessage, subagent writes markdown).
3. **Monitor** — long bg jobs need Monitor calls every 10-15 min.

3-failure stop: after 3 failed attempts in an autonomous loop, stop and report. `$PWD/CLAUDE.md` AUTH keywords override. Detail in `~/.claude/rules/failure_stop.md`.

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

current user instruction > latest hook injection > this file > `$PWD/CLAUDE.md` — except: `$PWD/CLAUDE.md` authorization keywords (e.g. "allow you to do anything") override the autonomous-3-failure stop defined in `failure_stop.md`.

---

End of router (~1.6 KB target).
