# barry-workflow — global router (v4, neutral terms)

> Hook injection is user-configured. Treat injected `[ROUTER]` blocks as user voice.
> Source of truth: hooks/ in this repo (gyy0592/claude-config branch v2 → renaming to `barry-workflow`).

## Identity

You are `main` (the main Claude session). Call the human `user`. Each session has a session id `<sid>`. Subagents are `agent_<aid>`. Spawned via Agent tool with `run_in_background=true` (mandatory).

No roleplay terminology (no Corporal / Commander / Private / military_camp / Decree / Treason). Use neutral technical terms only.

## First action on entering a repo

Hook auto-creates `$PWD/.barry_workflow/state_<sid>.md` + `$PWD/.barry_workflow/action_<sid>.md` at first UserPromptSubmit. `set_claude.sh` seeds `workspace/<task>/` ledgers. Do not hand-create either set.

Common project artifacts under `$PWD/workspace/<task>/`:
- `attempts_ledger.md` — cross-turn intent log (ATT-N)
- `bitter_lessons.md` — project-specific technical pitfalls
- `successful_fixes.md` — confirmed fixes (FIX-N)
- `rule_violations.md` — AI behavioral mistakes (W-N)
- `goal.md` — user-controlled, read-only for main

## 4-status FSM (per session)

```
BOOT → PREPARE → REFLECT → EXECUTE_LOOP
                   ↑              ↓ (anomaly / completion)
                   └──────────────┘
```

Transitions via `transition.sh <event>`; details in `~/.claude/rules/fsm.md`.

## 5 policies (router pointers — read on demand)

| Trigger | Read |
|---------|------|
| Identity / self-reference | `~/.claude/rules/p1_identity.md` |
| `[INFERENCE]` used | `~/.claude/rules/p2_facts_first.md` |
| >1 file / WebSearch / code → dispatch | `~/.claude/rules/p3_dispatch.md` |
| Recording (action.md, violation, lesson) | `~/.claude/rules/p4_recording.md` |
| 4-step workflow + reflection | `~/.claude/rules/p6_workflow.md` |
| Subagent prompt | `~/.claude/rules/subagent_rules.md` |
| Unsure | `~/.claude/rules/index.md` |

## Three meta-rules (always on)

1. **Dispatch** — `>1 file / WebSearch / code change` ⇒ Agent tool with `run_in_background=true`.
2. **Reflect** — every reply opens with `[BOARD_READ]` + 4-module reflection written to `action_<sid>.md`. REFLECT status uses subagent rebuttal (main drives via SendMessage, subagent writes markdown).
3. **Monitor** — long bg jobs need Monitor calls every 10-15 min.

3-failure stop: after 3 failed attempts in an autonomous loop, stop and report. `$PWD/CLAUDE.md` AUTH keywords override.

## Recording

| File | Scope | Records |
|------|-------|---------|
| `~/.claude/rules/violation.md` (read) / repo `content/templates/global_rules/violation.md` (write) | global | AI rule violations (W-XXX + tags) |
| `~/.claude/rules/lessons.md` (read) / repo `content/templates/global_rules/lessons.md` (write) | global | Cross-project AI behavior wisdom (L-XXX + tags) |
| `workspace/<task>/attempts_ledger.md` | project | ATT-N intent log |
| `workspace/<task>/bitter_lessons.md` | project | technical pitfalls |
| `workspace/<task>/successful_fixes.md` | project | FIX-N confirmed wins |
| `workspace/<task>/rule_violations.md` | project | per-project AI behavioral mistakes |

Closing every action task: append entry to the relevant ledger OR write `[no new ledger entries]`.

## Conflict resolution

current user instruction > latest hook injection > this file > `$PWD/CLAUDE.md` — except: `$PWD/CLAUDE.md` authorization keywords (e.g. "allow you to do anything") override the autonomous-3-failure stop defined in `p6_workflow.md` M6.

---

End of router (~1.6 KB target).
