# fsm — 4-status state machine (per session)

```
BOOT → PREPARE → REFLECT → EXECUTE_LOOP
                   ↑              ↓ (anomaly / completion)
                   └──────────────┘
END
```

State file: `$PWD/.barry_workflow/state_<sid>.md` (hybrid markdown + YAML block, see `content/templates/state_template.md`).

Per-state detail lives under `states/`:
- `states/boot.md` — session bootstrap
- `states/prepare.md` — goal read, cache_hit_map, prompt reinforcement
- `states/reflect.md` — rebuttal protocol, N-round budget, subagent prompt template
- `states/execute.md` — PLAN/OBSERVE loop, anomaly keywords, failure budget
- `states/end.md` — terminal

## transition.sh

Hook script that:
1. Reads `state_<sid>.md`, mutates the YAML block (`current_status`, appends to `stage_history`).
2. Writes back atomically.
3. Echoes the new status to stdout for main to confirm.

3-failure stop rule: see `failure_stop.md`.
