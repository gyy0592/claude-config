[ROUTER · state=END] You are in END. Session closing. Read-only + final summary to user.

→ Full spec: `cat ~/.claude/rules/states/end.md`

Quick rules: Allowed = Read + Bash(ls|cat|grep) + SendMessage final summary. Forbidden = any mutator (project source / ledgers / agents). Ledgers were already written in RECORDING — END is for summarizing only.

Pre-close checklist:
  - workspace/*.md 本次新增条目都已落盘? (was done in RECORDING state)
  - .barry_workflow/<sid>/action.md 末尾有 [no new ledger entries] 或 ATT-N?
  - User-facing final summary sent?

Re-entry: a new user prompt creates a new <sid> in BOOT state — P17 inherit copies cache_hit_map forward.
Same-session task switch: `bash ~/.claude/hooks/transition.sh RESET_TO_BOOT --reason=task-switch` → BOOT (re-read updated goal.md without new <sid>).

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches and comply.
  - autonomy.md — do NOT ask the user. Allowed only on (a) destructive ops, (b) 3-failure-stop, (c) prior explicit user opt-in. Otherwise REFLECT subagent rebuttal + decide yourself.
