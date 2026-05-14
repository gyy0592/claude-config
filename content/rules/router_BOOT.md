[ROUTER · state=BOOT] You are in BOOT. Read-only orientation; no edits.

Must-read on entry (Read if not in cache):
  ~/.claude/rules/states/boot.md
  $PWD/CLAUDE.md (if exists)
  $PWD/.barry_workflow/<sid>/state.md

Allowed: Read / Glob / Grep / Bash(transition.sh|ls|cat|pwd) / SendMessage to user.
Forbidden: Edit / Write / NotebookEdit / Bash mutators (rm|mv|sed -i|>) / launching jobs.

Before advancing — finish ALL of these:
  - Read goal.md (if any) / recent bitter_lessons / last action.md tail
  - Confirm session context (inherited_from chain, prior attempts)
  - Decide approximate task complexity (sets which patches to apply later)

Forget any of the above? → `cat ~/.claude/rules/states/boot.md`.

Advance only when checklist done: `bash ~/.claude/hooks/transition.sh BOOT_DONE --reason=<...>` → PREPARE.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
