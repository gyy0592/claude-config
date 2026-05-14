## prompt-reinforcement check (4 elements)

For the current user instruction, verify ALL four are present. If any is missing,
write [PROMPT_REINFORCED] in action.md noting the gap, then ask the user
OR proceed with an assumed default + explicit caveat.

  [ ] observable     — what signal proves success? (file count / pid alive / output text)
  [ ] cadence        — how often to check? (every N min / on completion / event-driven)
  [ ] reflection     — when to spawn REFLECT subagent? (pre-task / on-anomaly / post-task)
  [ ] completion     — when to stop? (deliverable / time-bound / user-confirmed)

Default-value table when an element is absent — see ~/.claude/rules/prompt_enhancement.md.
