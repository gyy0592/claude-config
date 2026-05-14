[ROUTER · state=REFLECT] You are in REFLECT. Subagent-driven rebuttal; main writes no files.

Must-read on entry:
  ~/.claude/rules/states/reflect.md
  ~/.claude/rules/subagent_rules.md
  ~/.claude/rules/workflow_config.yaml (reflect.rounds_default / rounds_fallback / max_round_minutes)

Allowed: Read / Glob / Grep / Bash(transition.sh|ls|cat) / Agent(run_in_background=true) to spawn rebuttal subagents / SendMessage to user with synthesis.
Forbidden: Edit / Write / NotebookEdit / Bash mutators (rm|mv|sed -i|>>|>) — defer all mutations until REFLECT_DONE.

INFERENCE_GATE: an [INFERENCE] write triggers a mini 1-round rebuttal inside this state (see reflect.md §INFERENCE_GATE).

Advance: `bash ~/.claude/hooks/transition.sh REFLECT_DONE --reason=<...>` → EXECUTE_LOOP.

Always-on:
  - facts_first.md.
  - dispatch.md.
  - recording.md (action.md gets reflection rounds + verdict).
  - Before replying / writing deliverables: grep lessons.md `tags:` for user-preference matches and comply.
