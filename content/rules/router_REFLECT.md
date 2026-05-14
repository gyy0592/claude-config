[ROUTER · state=REFLECT] You are in REFLECT. Subagent-driven rebuttal; main writes no files.

Must-read on entry:
  ~/.claude/rules/states/reflect.md
  ~/.claude/rules/subagent_rules.md
  ~/.claude/rules/workflow_config.yaml (reflect.rounds_default / rounds_fallback / max_round_minutes)

Allowed: Read / Glob / Grep / Bash(transition.sh|ls|cat) / Agent(run_in_background=true) to spawn rebuttal subagents / SendMessage to user with synthesis.
Forbidden: Edit / Write / NotebookEdit / Bash mutators (rm|mv|sed -i|>>|>) — defer all mutations until REFLECT_DONE.

INFERENCE_GATE: an [INFERENCE] write triggers a mini 1-round rebuttal inside this state (see reflect.md §INFERENCE_GATE).

Before advancing — finish ALL of these:
  - Rebuttal subagent spawned; reflection_<round>.md exists with `## reviewer reply`
  - SendMessage round(s) until `[CONSENSUS_REACHED]` written OR round budget exhausted (N=5 default, then fallback N=10)
  - Subagent agent shut down (TaskStop)
  - Consensus action list captured in action.md

Forget any of the above? → `cat ~/.claude/rules/states/reflect.md` + `cat ~/.claude/rules/subagent_rules.md`.

Advance only when checklist done: `bash ~/.claude/hooks/transition.sh REFLECT_DONE --reason=<...>` → EXECUTE_LOOP.

Always-on:
  - facts_first.md.
  - dispatch.md.
  - recording.md (action.md gets reflection rounds + verdict).
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
