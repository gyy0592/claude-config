# fsm — 6-status state machine (per session, v2.4)

```
BOOT → PREPARE → REFLECT ◄═══════► EXECUTE_LOOP
                   │  ▲ NEED_RECORD     │
                   ▼  │                 ▼ EXECUTE_EXIT (mandatory pass-through)
                RECORDING ◄─────────────┘
                   │ RECORD_DONE       ▲
                   ▼                   │ BACK_TO_LOOP (mid-task: record + resume)
                  END
```

Key v2.4 changes: `EXECUTE_EXIT` now routes EXECUTE_LOOP → RECORDING (not REFLECT). Ledger writes happen in RECORDING, not END. New events: `NEED_RECORD`, `RECORD_DONE`, `BACK_TO_LOOP`. `state.md` has new `prev_status` field.

State file: `$PWD/.barry_workflow/state_<sid>.md` (hybrid markdown + YAML block, see `content/templates/state_template.md`).

Per-state detail lives under `states/`:
- `states/boot.md` — session bootstrap
- `states/prepare.md` — goal read, cache_hit_map, prompt reinforcement
- `states/reflect.md` — rebuttal protocol, N-round budget, subagent prompt template
- `states/execute.md` — PLAN/OBSERVE loop, anomaly keywords, failure budget
- `states/recording.md` — dedicated ledger-writing state (v2.4)
- `states/end.md` — final user-facing summary only (ledger writes done in RECORDING)

## transition.sh

Hook script that:
1. Reads `state_<sid>.md`, mutates the YAML block (`current_status`, appends to `stage_history`).
2. Writes back atomically.
3. Echoes the new status to stdout for main to confirm.

3-failure stop rule: see `failure_stop.md`.
