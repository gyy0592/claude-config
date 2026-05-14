# Rebuttal round 1 — CLAUDE_v4_draft.md review

main's proposal: replace 113-line cosplay-heavy `~/.claude/CLAUDE.md` with neutral 60-line router (see `CLAUDE_v4_draft.md` sibling).

**Questions for reviewer subagent (write reply below `## reviewer reply`):**

1. Are any load-bearing semantics from the old CLAUDE.md lost? (Decrees D1-D6, Iron Rules, 3-step opening, REFLECT-A 6-row table, BOARD_READ procedure, on-demand read triggers)
2. Does the neutral terminology drift too far from the source content the rules/*.md files (when written) will need to absorb? List concrete gaps.
3. Is the conflict-resolution paragraph still accurate (AUTH override for 3-failure stop)?
4. The draft drops `init_corporal.sh` / `militar_camp/` references. Replacement is `workspace/<task>/` + hook-built `.barry_workflow/`. Acceptable transition path?
5. Is the FSM mention (single line "detail in fsm.md") enough or does the router itself need to inline the 4-status diagram?

Write `## reviewer reply` below with concrete diff suggestions (location + before + after), not just "fine".

## reviewer reply

### Q1 — Load-bearing semantics lost from old CLAUDE.md

Several load-bearing items are absent and not deferred to a named rules/*.md target. The draft says "policies — read on demand" but doesn't promise that the policy files exist or what they must contain. Concrete gaps:

- **3-step opening procedure** (`[BOARD_READ]` → 4-module reflection → respond). The old §1 mandates this every reply. Draft has no mention. Either (a) move it into `p6_workflow.md` and name it, or (b) inline a one-liner pointer.
- **REFLECT-A 6-row table** (one row per policy with ✓/✗ + evidence). This is the anti-decay enforcement mechanism. Drop without replacement = the FSM `REFLECT` state has no defined output shape.
- **Pre-check checklist (a–e)** from old §2 — these are the per-turn audit questions. Not visible in draft.
- **3-failure stop rule** referenced in Conflict resolution line but never defined. New reader has no idea what "3-failure stop rule" means.
- **5-file recording table preserved** (good), but old §4 also encoded *when* to append ("Closing every action task: append entry … OR write `[no new ledger entries]`"). Drop this and ledgers will rot.

Suggested diff at draft line 38–43:

```
## Three meta-rules (always on)

1. Dispatch — >1 file / WebSearch / code change ⇒ Agent tool with run_in_background=true.
2. Reflect — every reply opens with [BOARD_READ] + 4-module reflection written to action_<sid>.md.
   REFLECT state uses subagent rebuttal (main drives via SendMessage, subagent writes markdown).
3. Monitor — long bg jobs need Monitor calls every 10–15 min.

3-failure stop: after 3 failed attempts in an autonomous loop, stop and report.
$PWD/CLAUDE.md AUTH keywords override.
```

### Q2 — Terminology drift vs source absorbed into rules/*.md

Draft is fine on this axis. Neutral mapping (main/agent/user) is consistent with v4_plan §0.2. One nit at line 8:

Before: `Subagents are agent_<aid> (dispatched via Agent tool with run_in_background=true).`
After: `Subagents are agent_<aid>. Spawned via Agent tool with run_in_background=true (mandatory).`

The "mandatory" word is in v4_plan but missing here, weakens dispatch policy.

### Q3 — Conflict resolution accuracy

Inaccurate as written. Line 58 says "AUTH keywords override the 3-failure stop rule" but the rule itself isn't defined in the draft (see Q1). Either define it inline or stop referencing it:

Before: `… except: $PWD/CLAUDE.md AUTH keywords override the 3-failure stop rule.`
After: `… except: $PWD/CLAUDE.md authorization keywords (e.g. "allow you to do anything") override the autonomous-3-failure stop defined in p6_workflow.md M6.`

### Q4 — init_corporal.sh / militar_camp → workspace/ + .barry_workflow/

Acceptable. Draft line 14 covers it. One concrete gap: old CLAUDE.md said "Do not hand-create any militar_camp/ files." Draft says "Do not hand-create these" but only refers to two files (state_<sid>.md, action_<sid>.md). The `workspace/<task>/` ledgers (attempts_ledger, bitter_lessons, …) are also hook/script-created per v4_plan §2 Status 1 ("set_claude.sh 一次部署"). Make this explicit:

Before (line 14): `Hook auto-creates $PWD/.barry_workflow/state_<sid>.md + action_<sid>.md at first UserPromptSubmit. Do not hand-create these.`
After: `Hook auto-creates $PWD/.barry_workflow/state_<sid>.md + action_<sid>.md at first UserPromptSubmit. set_claude.sh seeds workspace/<task>/ ledgers. Do not hand-create either set.`

### Q5 — FSM mention: inline diagram or pointer-only?

Pointer-only is too thin. The FSM is one of the v4 "must-do" items per plan §1, and other parts of the router (e.g. REFLECT state, EXECUTE_LOOP exit by AI self-judge) reference state names that a reader cannot resolve without opening fsm.md. Inline the 4-state diagram — it costs ~5 lines and removes a forced indirection:

Before (lines 23–25):
```
## 4-status FSM (per session)
`BOOT → PREPARE → REFLECT → EXECUTE_LOOP` (REFLECT ↔ EXECUTE on anomaly / completion). Detail in `~/.claude/rules/fsm.md`.
```

After:
```
## 4-status FSM (per session)

```
BOOT → PREPARE → REFLECT → EXECUTE_LOOP
                   ↑              ↓ (anomaly / completion)
                   └──────────────┘
```
Transitions via `transition.sh <event>`; details in `~/.claude/rules/fsm.md`.
```

### Summary

Draft is structurally on-target but **under-specifies three things**: opening procedure, 3-failure stop definition, and FSM transitions. Fix those four diffs above and it's ready. Length budget (~1.5 KB) still met with the additions (~+20 lines).
