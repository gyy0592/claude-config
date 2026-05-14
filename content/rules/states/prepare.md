# PREPARE state

Entered after BOOT_DONE. Main duties:

1. Read `goal.md` (if present). Treat as read-only.
2. Write the **cache_hit_map** YAML block in `state_<sid>.md`: list which artifacts (rules, ledgers, recent action entries) are already in the KV cache from prior turns vs which must be re-Read this turn. Misjudgment = AI behavioral error → `rule_violations.md` (not `bitter_lessons.md`).
3. Prompt-reinforcement check: confirm the user instruction contains the 4 required elements (observable / cadence / reflection / completion). If any missing, write `[PROMPT_REINFORCED]` in action_<sid>.md with the gap noted.
4. Call `transition.sh PREPARE_DONE` to advance to REFLECT.

(Tunables — see `workflow_config.yaml` `prompt_reinforce.required_elements`.)
