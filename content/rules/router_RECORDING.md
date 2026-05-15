[ROUTER · state=RECORDING] You are in RECORDING. Focus: append entries to ledgers, no project work.

→ Full pipeline (4 self-check questions / append targets / closing): `cat ~/.claude/rules/states/recording.md`
→ Advance: `bash ~/.claude/hooks/transition.sh RECORD_DONE --reason="<short>"` → END
→ Mid-task resume: `bash ~/.claude/hooks/transition.sh BACK_TO_LOOP --reason="<short>"` → prev state (EXECUTE_LOOP / REFLECT)

Quick rules: Allowed = Read + Bash(transition.sh|ls|cat|grep) + append-only Write/Edit to workspace/*.md + content/templates/global_rules/*.md + .barry_workflow/<sid>/action.md. Forbidden = project source mutations / Agent spawn / Bash mutators on project files.

Self-check before transitioning out (answer all 4):
  1. 项目技术坑（lib 不兼容 / 配置组合 / 硬件怪癖）? → workspace/bitter_lessons.md L-N (`task:` + `tags:`)
  2. 确认成功的 fix（3-Q 通过）? → workspace/successful_fixes.md FIX-N (`task:` + `tags:`)
  3. AI 自身违规（跳 dispatch / 漏 PLAN / record-skip）? → workspace/rule_violations.md W-N (`task:` + `tags:`)
  4. 上述 1-3 有跨项目意义? → 加写 content/templates/global_rules/{lessons,violation}.md

Per-turn intent log: append ATT-N to workspace/attempts_ledger.md (`task:` + `tags:` + one-line intent).
If 4 都是 "no": write `[no new ledger entries]` to action.md and transition.

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches and comply.
