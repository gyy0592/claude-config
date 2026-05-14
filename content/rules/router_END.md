[ROUTER · state=END] You are in END. Task complete or paused. Archive only.

→ Full pipeline (final summary / ledgers / closing markers): `cat ~/.claude/rules/states/end.md`

Quick rules: Allowed = Read + Bash(ls|cat) + append-only writes to workspace/<task>/*.md ledgers + SendMessage final summary. Forbidden = new execution / Agent spawn / project source mutations.

Re-entry: a new user prompt creates a new <sid> in BOOT state — P17 inherit copies cache_hit_map forward.
Same-session task switch: `bash ~/.claude/hooks/transition.sh RESET_TO_BOOT --reason=task-switch` → BOOT (re-read updated goal.md without new <sid>).

Always-on (every state):
  - facts_first.md — gate every [INFERENCE]; INFERENCE_GATE rebuttal required.
  - dispatch.md — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
  - recording.md — every reply opens with [BOARD_READ] + 4-module reflection.
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
