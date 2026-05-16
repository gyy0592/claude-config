[ROUTER · state=REFLECT] **First action MUST be `Agent(run_in_background=true)` to spawn a rebuttal subagent.** Before that subagent writes content into `## reviewer reply` of `.barry_workflow/<sid>/reflection_*.md`, no other tool call is allowed — except Read on reference docs and Write/append confined to `.barry_workflow/<sid>/reflection_*.md` (rebuttal scratch). All project source / ledger writes are forbidden in this state.

→ Full pipeline (rebuttal protocol / N rounds / CONSENSUS): `cat ~/.claude/rules/states/reflect.md`
→ Subagent constraints: `cat ~/.claude/rules/subagent_rules.md`
→ Advance when consensus reached: `bash ~/.claude/hooks/transition.sh REFLECT_DONE --reason="<short>"` → EXECUTE_LOOP
→ Mid-state record (without leaving REFLECT): `bash ~/.claude/hooks/transition.sh NEED_RECORD --reason="<short>"` → RECORDING, then `BACK_TO_LOOP` returns here
→ User changed task mid-session: `bash ~/.claude/hooks/transition.sh RESET_TO_BOOT --reason=task-switch` → BOOT

Quick rules: Allowed = Read + Bash(transition.sh|ls|cat) + background subagent dispatch + push reply to subagent + Write/append to `.barry_workflow/<sid>/reflection_*.md`. Forbidden = Edit/Write/NotebookEdit on project source / ledgers + Bash mutators — defer real mutations until REFLECT_DONE.

INFERENCE_GATE: writing [INFERENCE] triggers a mini 1-round rebuttal inside this state (see reflect.md).

Recording reminder (always-on in REFLECT):
  本轮有无任何记账值得做? — 项目技术坑 / 成功 fix / AI 自身违规 / 跨项目智慧
  → 有 → `bash ~/.claude/hooks/transition.sh NEED_RECORD --reason="<one-line>"` 进 RECORDING
  → 无 → 在 action.md 写 `[no new ledger entries this turn]` 显式声明

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ background subagent dispatch.
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
  - autonomy.md — do NOT ask the user. Allowed only on (a) destructive ops, (b) 3-failure-stop, (c) prior explicit user opt-in. Otherwise REFLECT subagent rebuttal + decide yourself.
