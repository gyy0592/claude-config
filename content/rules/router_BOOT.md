[ROUTER · state=BOOT] **READ-ONLY. Forbidden: Edit / Write / NotebookEdit / Agent / Bash mutators (rm/mv/sed -i/redirection/tee).** Only write allowed: appending one `[BOOT_NOTE complexity=<class>]` line to `.barry_workflow/<sid>/action.md`. Every other mutator must wait until BOOT_DONE.

→ Full pipeline + completion criteria: `cat ~/.claude/rules/states/boot.md`
→ Advance when checklist done: `bash ~/.claude/hooks/transition.sh BOOT_DONE --reason="<short>"` → PREPARE

Quick rules: Allowed = Read/Glob/Grep + Bash(transition.sh|ls|cat|pwd). Forbidden = Edit/Write/mutators/Agent.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ background subagent dispatch.
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - 4-ledger check — before replying, confirm cache_hit_map has hit: YES for all 4 error files: (1) ~/.claude/rules/lessons.md (2) ~/.claude/rules/violation.md (3) workspace/bitter_lessons.md (4) workspace/rule_violations.md. Any hit: NO → Read it now. Then grep all 4 for tags matching current task and comply.
  - autonomy.md — do NOT ask the user. Allowed only on (a) destructive ops, (b) 3-failure-stop, (c) prior explicit user opt-in. Otherwise REFLECT subagent rebuttal + decide yourself.
