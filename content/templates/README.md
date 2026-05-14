# content/templates/ — barry-workflow runtime artifact templates

Source-of-truth templates copied / referenced by `set_claude.sh`, `new_task.sh`, and the BOOT hook (`session_boot.sh`). At runtime: per-session state lives under `$PWD/.barry_workflow/<sid>/`; shared project ledgers (`bitter_lessons`, `successful_fixes`, `attempts_ledger`, `rule_violations`) live at `$PWD/workspace/`; per-task goals at `$PWD/workspace/<task>/goal.md`.

## Kept (v2.1)

| File | Used by | Purpose |
|------|---------|---------|
| `state_template.md` | `session_boot.sh` | Seeds `$PWD/.barry_workflow/state_<sid>.md` — hybrid markdown + YAML state block. |
| `action_template.md` | `session_boot.sh` | Seeds `$PWD/.barry_workflow/action_<sid>.md` — per-turn `[PLAN]/[OBSERVE]` log. |
| `reflection_template.md` | `states/reflect.md` | main interpolates session id / reason / round id to create `reflection_<round_id>.md`. |
| `bitter_lessons.md` | project ledger | Project-specific technical pitfalls (config combos that break, library incompatibilities). |
| `attempts_ledger.md` | project ledger | ATT-N cross-turn intent log. |
| `successful_fixes.md` | project ledger | FIX-N confirmed wins. |
| `goal.md` | project | User-controlled, read-only for main. |
| `global_rules/violation.md` | deployed to `~/.claude/rules/violation.md` | Cross-project AI rule violations (W-XXX). |
| `global_rules/lessons.md` | deployed to `~/.claude/rules/lessons.md` | Cross-project AI behavior wisdom (L-XXX). |

## Removed (v2.1 P18)

Dropped v1 cosplay templates: `corporal_situation.md`, `corporal_action.md`, `corporal_status.md`, `soldier_action.md`, `soldier_status.md`, `warning_board.md`, `reward_board.md`, `traitor.md`, `operation_log.md`, `status.md`.

The state-machine FSM (`fsm.md` + `states/*.md`) and the per-session `.barry_workflow/{state,action,reflection}_<sid>.md` layout replace the v1 `militar_camp/corporal_X/numberY/` skeleton.

## Write rules

- Append only, never overwrite.
- Write step by step; do not batch-write at task end.
- Tag claims `[FACT]/[INFERENCE]/[ASSUMPTION]` per `~/.claude/rules/facts_first.md`.
