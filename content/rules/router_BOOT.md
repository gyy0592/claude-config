[ROUTER · state=BOOT] You are in BOOT. Read-only orientation, no mutations.

→ Full pipeline + completion criteria: `cat ~/.claude/rules/states/boot.md`
→ Advance when checklist done: `bash ~/.claude/hooks/transition.sh BOOT_DONE --reason="<short>"` → PREPARE

Quick rules: Allowed = Read/Glob/Grep + Bash(transition.sh|ls|cat|pwd). Forbidden = Edit/Write/mutators/Agent.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
  - autonomy.md — **never stop, only ask-while-working**. Ship artifacts this turn (or transition.sh to next state if BOOT); ask in parallel if must. Stop only on destructive / 3-failure / explicit opt-in.
