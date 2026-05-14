# fsm — 4-status state machine (per session)

```
BOOT → PREPARE → REFLECT → EXECUTE_LOOP
                   ↑              ↓ (anomaly / completion)
                   └──────────────┘
END
```

State file: `$PWD/.barry_workflow/state_<sid>.md` (hybrid markdown + YAML block, see `state_template.md`).

## States

### BOOT
- UserPromptSubmit hook creates `state_<sid>.md` + `action_<sid>.md` if missing (`current_status: BOOT`).
- main writes `[BOOT_DONE @ ts]` to action and calls `transition.sh BOOT_DONE`.

### PREPARE
- main reads `goal.md` + writes the **cache_hit_map** YAML block (which artifacts already in KV cache from prior turns vs which must be re-read).
- Misjudged cache → AI behavioral error → `rule_violations.md` (not `bitter_lessons.md`).
- Prompt-reinforcement check: confirm user instruction has 4 elements (observable / cadence / reflection / completion); if missing, write `[PROMPT_REINFORCED]` with the gap noted.
- `transition.sh PREPARE_DONE`.

### REFLECT (entered from PREPARE or EXECUTE_LOOP)
- Spawn a subagent via `Agent(run_in_background=true)` with reason=`pre-task | on-anomaly | post-task`.
- Use the rebuttal protocol (`subagent_rules.md` rule F).
- On `[CONSENSUS_REACHED]` or N=5 (fallback 10) rounds: `transition.sh REFLECT_DONE`.

### EXECUTE_LOOP
Inner loop (one iteration = one tool call):
1. `[PLAN]` — one line in action_<sid>.md describing what + why + expected observable, BEFORE the tool call.
2. Tool call (Read / Edit / Write / Bash / Agent).
3. `[OBSERVE]` — one line in action_<sid>.md citing the concrete output that confirms or refutes the [PLAN] expectation. Empty / hand-waved [OBSERVE] = dereliction.
4. Decide: continue (another iteration), anomaly (→ REFLECT on-anomaly), or done (→ REFLECT post-task).

Monitor cadence for bg jobs spawned inside EXECUTE_LOOP:
- Wall-time < 5 min → check once on completion notification.
- 5–60 min → `Monitor(bash_id=...)` every 10–15 min. **Monitor blocks the main thread up to `timeout_ms` (default 5 min, max 1 hr)** — this is how main "sleeps" inside one turn without burning context on idle polls.
- > 60 min → use `Monitor(persistent=true)` or split via `CronCreate` (cross-session). Also write `[SILENCE_START]` block in action.md naming task / ETA / completion marker — note that `[SILENCE_START]` is an **audit marker only**, no hook enforces it; the actual sleep mechanism is Monitor or task_notification waiting.

Anomaly keywords (used by `execute_loop_audit.sh` to count failure budget):
`refuted | anomaly | fail(ed|ure)? | stuck | unchanged | timeout | exit code [1-9] | traceback | OOM | killed | crash | hang` (case-insensitive). When you write `[OBSERVE]` and the result disagrees with `[PLAN]`, include at least one of these words so the auditor counts it.

Failure budget: after 3 consecutive [OBSERVE] entries refuting their [PLAN]
in the same EXECUTE_LOOP session, stop and call `transition.sh EXECUTE_EXIT
--reason=bug` (autonomous-3-failure rule from `p6_workflow.md` M6). Override:
$PWD/CLAUDE.md AUTH keywords.

Exit call: `transition.sh EXECUTE_EXIT --reason=<bug|done|stuck>`. AI is the sole
judge of which reason applies — observable evidence must back the choice.

## transition.sh
Hook script that:
1. Reads `state_<sid>.md`, mutates the YAML block (`current_status`, appends to `stage_history`).
2. Writes back atomically.
3. Echoes the new status to stdout for main to confirm.
