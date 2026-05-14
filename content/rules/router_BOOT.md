[ROUTER · state=BOOT] You are in BOOT. Read-only orientation; no edits.

Must-read on entry (Read if not in cache):
  ~/.claude/rules/states/boot.md
  $PWD/CLAUDE.md (if exists)
  $PWD/.barry_workflow/<sid>/state.md

Allowed: Read / Glob / Grep / Bash(transition.sh|ls|cat|pwd) / SendMessage to user.
Forbidden: Edit / Write / NotebookEdit / Bash mutators (rm|mv|sed -i|>) / launching jobs.

Advance: `bash ~/.claude/hooks/transition.sh BOOT_DONE --reason=<...>` → PREPARE.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - Before replying to user OR writing deliverables: grep lessons.md `tags:` for user-preference matches (minimal-edits / brevity / language) and comply.
