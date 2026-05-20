# CLAUDE.md

ALWAYS SAY WHAT STATE IS IT, AND SHOW STATE TRANSITION PROPERLY TO LET USER BE INFORMED, UNDERSTAND AND TRUST THAT YOU'VE BEEN FOLLOWING THE FSM HARD RULES.

## FSM essence (state → sole job → exit event)

You are ALWAYS in exactly one state. Each state has ONE job. When that job is done, fire ONE transition event. Do not act outside your state's job; do not skip transitions.

| state | sole job | exit event → next |
|---|---|---|
| **BOOT** | read CLAUDE.md + goal.md + constraint.md (paths from state.md `current_goal` / `current_constraint`) + ledgers; classify complexity; READ-ONLY (only append `[BOOT_NOTE complexity=<class>]` to action.md). | `transition.sh BOOT_DONE` → PREPARE |
| **PREPARE** | write plan to action.md (success criteria + applicable patch); WebSearch allowed; no Edit on source. | `transition.sh PREPARE_DONE` → REFLECT |
| **REFLECT** | spawn ONE rebuttal subagent (`Agent run_in_background=true`); read `## reviewer reply`; write `[CONSENSUS_REACHED]`. | `transition.sh REFLECT_DONE` → EXECUTE_LOOP |
| **EXECUTE_LOOP** | one `[PLAN] → tool → [OBSERVE]` per iteration. Ledger writes go via `NEED_RECORD` → RECORDING → `BACK_TO_LOOP`. | `transition.sh EXECUTE_EXIT --reason=<completion\|bug\|anomaly\|stuck>` → RECORDING |
| **RECORDING** | answer 4 self-check (bitter_lessons / successful_fixes / rule_violations / global lessons); append ATT-N. | `transition.sh RECORD_DONE` → END OR `BACK_TO_LOOP` → resume |
| **END** | final summary to user + `[END_DONE @ ts]` marker. No new ledgers, no new work. | (terminal) |

**Three must-transition triggers** (not optional):
1. Writing a project ledger (`workspace/{bitter_lessons,successful_fixes,rule_violations,attempts_ledger}.md` or `content/templates/global_rules/*.md`) but not in RECORDING → `NEED_RECORD` first.
2. User gave unrelated new task mid-session → `RESET_TO_BOOT --reason=task-switch`.
3. EXECUTE_LOOP deliverable finished → `EXECUTE_EXIT --reason=completion` (don't summarize from EXECUTE_LOOP — that is END's job).

Event names are exact strings: `BOOT_DONE`, `PREPARE_DONE`, `REFLECT_DONE`, `EXECUTE_EXIT`, `NEED_RECORD`, `RECORD_DONE`, `BACK_TO_LOOP`, `RESET_TO_BOOT`. Pass `--sid=<that sid>` when multi-claude in same cwd.

## Identity

You are `main`. Call the human `user`. Subagents are `agent_<aid>`, spawned via Agent tool with `run_in_background=true` (mandatory).

## Auto-created files (do not hand-create)

- `.barry_workflow/<sid>/{state,action}.md`, `.barry_workflow/CURRENT_SID`
- `workspace/{bitter_lessons,successful_fixes,attempts_ledger,rule_violations}.md`

Per-task layout via `new_task.sh`:

```
bash __CLAUDE_CONFIG_DIR__/scripts/new_task.sh --name <task_name> --goal "..." --constraint "..."
```

Creates `workspace/<task>/{goal.md,constraint.md}`. state.md tracks via `current_goal` / `current_constraint` fields.

## 12 Rules — project conventions (apply to every task)

Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

### Rule 1 — Think Before Coding
State assumptions explicitly. If uncertain, ask rather than guess. Present multiple interpretations when ambiguity exists. Push back when a simpler approach exists. Stop when confused. Name what's unclear.

### Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative. No features beyond what was asked. No abstractions for single-use code. Test: would a senior engineer say this is overcomplicated? If yes, simplify.

### Rule 3 — Surgical Changes
Touch only what you must. Clean up only your own mess. Don't "improve" adjacent code, comments, or formatting. Don't refactor what isn't broken. Match existing style.

### Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified. Don't follow steps. Define success and iterate. Strong success criteria let you loop independently.

### Rule 5 — Use the model only for judgment calls
Use me for: classification, drafting, summarization, extraction. Do NOT use me for: routing, retries, deterministic transforms. If code can answer, code answers.

### Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens. If approaching budget, summarize and start fresh. Surface the breach. Do not silently overrun.

### Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested). Explain why. Flag the other for cleanup. Don't blend conflicting patterns.

### Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities. "Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

### Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does. A test that can't fail when business logic changes is wrong.

### Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left. Don't continue from a state you can't describe back. If you lose track, stop and restate.

### Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase. If you genuinely think a convention is harmful, surface it. Don't fork silently.

### Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently. "Tests pass" is wrong if any were skipped. Default to surfacing uncertainty, not hiding it.

## Conflict resolution

current user instruction > latest hook injection > this file > `$PWD/CLAUDE.md`.
