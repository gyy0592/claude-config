[ROUTER · state=END] You are in END. Task complete or user-paused. Archive only.

Must-read on entry:
  ~/.claude/rules/states/end.md
  ~/.claude/rules/recording.md

Allowed: Read / Bash(ls|cat) / append to attempts_ledger.md|bitter_lessons.md|successful_fixes.md / SendMessage final summary to user.
Forbidden: starting new execution / spawning execution agents / mutating project source files.

Re-entry: a new user prompt creates a new <sid> (BOOT) — P17 inherit copies cache_hit_map forward.

Always-on:
  - facts_first.md.
  - recording.md (ledger entries before reply ends).
  - Before replying / writing deliverables: grep lessons.md `tags:` for user-preference matches and comply.
