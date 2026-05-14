[ROUTER · state=REFLECT] You are in REFLECT. Subagent-driven rebuttal, main writes no files.

→ Full pipeline (rebuttal protocol / N rounds / CONSENSUS): `cat ~/.claude/rules/states/reflect.md`
→ Subagent constraints: `cat ~/.claude/rules/subagent_rules.md`
→ Advance when consensus reached: `bash ~/.claude/hooks/transition.sh REFLECT_DONE --reason="<short>"` → EXECUTE_LOOP

Quick rules: Allowed = Read + Bash(transition.sh|ls|cat) + Agent(run_in_background=true) for rebuttal subagent + SendMessage. Forbidden = Edit/Write/NotebookEdit + Bash mutators — defer mutations until REFLECT_DONE.

INFERENCE_GATE: writing [INFERENCE] triggers a mini 1-round rebuttal inside this state (see reflect.md).

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
