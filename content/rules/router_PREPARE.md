[ROUTER · state=PREPARE] You are in PREPARE. Build cache_hit_map, draft plan; no execution.

Must-read on entry:
  ~/.claude/rules/states/prepare.md
  ~/.claude/rules/prompt_enhancement.md (4-element check + default suggestions)
  ~/.claude/rules/workflow_config.yaml (prompt_reinforce.required_elements)
  $PWD/.barry_workflow/<sid>/state.md (cache_hit_map row UNKNOWN → Read source artifact)

Helpers:
  bash ~/.claude/hooks/prepare_helper.sh   # emit cache_hit_map stub + 4-element checklist

Allowed: Read / Glob / Grep / Bash(prepare_helper.sh|transition.sh|ls|cat) / planning notes in action.md.
Forbidden: Edit / Write of project files / launching jobs / spawning execution agents.

Before advancing — finish ALL of these:
  - cache_hit_map filled (every artifact UNKNOWN → YES/NO)
  - 4-element check done (observable / cadence / reflection / completion); [PROMPT_REINFORCED] written if any missing
  - Plan written to action.md (intended deliverable + success criteria)
  - Patches scanned: any `~/.claude/rules/patches/*.md` whose `applies_to` matches this task → Read

Forget any of the above? → `cat ~/.claude/rules/states/prepare.md` + `cat ~/.claude/rules/prompt_enhancement.md`.

Advance only when checklist done: `bash ~/.claude/hooks/transition.sh PREPARE_DONE --reason=<...>` → REFLECT.

Always-on:
  - facts_first.md (INFERENCE_GATE).
  - dispatch.md.
  - recording.md.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
