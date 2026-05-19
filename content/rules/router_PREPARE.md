[ROUTER · state=PREPARE] You are in PREPARE. Build cache_hit_map + plan, no execution.

→ Full pipeline + completion criteria: `cat ~/.claude/rules/states/prepare.md`
→ 4-element check defaults: `cat ~/.claude/rules/prompt_enhancement.md`
→ Helper: `bash ~/.claude/hooks/prepare_helper.sh`
→ Advance when checklist done: `bash ~/.claude/hooks/transition.sh PREPARE_DONE --reason="<short>"` → REFLECT

Quick rules: Allowed = Read/Glob/Grep/WebSearch + planning notes to action.md. Forbidden = Edit/Write to source / Agent / bg jobs / tests.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - 4-ledger check — before replying, confirm cache_hit_map has hit: YES for all 4 error files: (1) ~/.claude/rules/lessons.md (2) ~/.claude/rules/violation.md (3) workspace/bitter_lessons.md (4) workspace/rule_violations.md. Any hit: NO → Read it now. Then grep all 4 for tags matching current task and comply.
  - autonomy.md — **never stop, only ask-while-working**. Ship artifacts this turn (or transition.sh to next state if BOOT); ask in parallel if must. Stop only on destructive / 3-failure / explicit opt-in.
