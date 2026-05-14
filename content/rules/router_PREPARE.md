[ROUTER · state=PREPARE] You are in PREPARE. Build cache_hit_map, draft plan; no execution.

Must-read on entry:
  ~/.claude/rules/states/prepare.md
  ~/.claude/rules/workflow_config.yaml (prompt_reinforce.required_elements)
  $PWD/.barry_workflow/<sid>/state.md (cache_hit_map row UNKNOWN → Read source artifact)

Helpers:
  bash ~/.claude/hooks/prepare_helper.sh   # emit cache_hit_map stub + 4-element checklist

Allowed: Read / Glob / Grep / Bash(prepare_helper.sh|transition.sh|ls|cat) / planning notes in action.md.
Forbidden: Edit / Write of project files / launching jobs / spawning execution agents.

Advance: `bash ~/.claude/hooks/transition.sh PREPARE_DONE --reason=<...>` → REFLECT.

Always-on:
  - facts_first.md (INFERENCE_GATE).
  - dispatch.md.
  - recording.md.
  - Before replying / writing deliverables: grep lessons.md `tags:` for user-preference matches and comply.
