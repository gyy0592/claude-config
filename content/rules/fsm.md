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
- Inner loop: `[PLAN]` → tool call → `[OBSERVE]` → decide (continue / anomaly / done).
- main exits when self-judged: bug → REFLECT (on-anomaly); deliverable complete → REFLECT (post-task).
- Exit call: `transition.sh EXECUTE_EXIT --reason=<bug|done>`.

## transition.sh
Hook script that:
1. Reads `state_<sid>.md`, mutates the YAML block (`current_status`, appends to `stage_history`).
2. Writes back atomically.
3. Echoes the new status to stdout for main to confirm.
