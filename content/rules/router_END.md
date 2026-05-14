[ROUTER · state=END] You are in END. Task complete or user-paused. Archive only.

Must-read on entry:
  ~/.claude/rules/states/end.md
  ~/.claude/rules/recording.md

Allowed: Read / Bash(ls|cat) / append to attempts_ledger.md|bitter_lessons.md|successful_fixes.md / SendMessage final summary to user.
Forbidden: starting new execution / spawning execution agents / mutating project source files.

Before closing — finish ALL of these:
  - ledger entry written to attempts_ledger.md / successful_fixes.md / bitter_lessons.md OR `[no new ledger entries]`
  - Final summary to user delivered (deliverable list + caveats)
  - No half-finished work left in action.md

Forget any of the above? → `cat ~/.claude/rules/states/end.md`.

Re-entry: a new user prompt creates a new <sid> (BOOT) — P17 inherit copies cache_hit_map forward.

Always-on:
  - facts_first.md.
  - recording.md (ledger entries before reply ends).
  - lessons.md grep — before replying to user OR writing deliverables, grep ~/.claude/rules/lessons.md `tags:` for matches (minimal-edits / brevity / language / scope-creep / etc.) and comply.
