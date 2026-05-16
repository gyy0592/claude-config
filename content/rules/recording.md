# recording

Record before acting. Every meaningful operation (file edit, long Bash, Agent spawn, config change) gets a one-line `[PLAN]` entry in `$PWD/.barry_workflow/action_<sid>.md` *before* the tool call. Confession without a file record = double violation.

Recording targets:

| File | Scope | Contents |
|------|-------|----------|
| `content/templates/global_rules/violation.md` (repo) → deployed to `~/.claude/rules/violation.md` | global | AI behavioral violations (W-XXX + tags). Write to repo path (no approval click). |
| `content/templates/global_rules/lessons.md` (repo) → deployed to `~/.claude/rules/lessons.md` | global | Cross-project AI behavior wisdom (L-XXX + tags). |
| `$PWD/workspace/attempts_ledger.md` | project (shared) | ATT-N cross-turn intent log; each entry has `task: <name>` + `tags:`. |
| `$PWD/workspace/bitter_lessons.md` | project (shared) | Project-technical pitfalls (config combos, lib incompat, hardware quirks); `task:` + `tags:`. |
| `$PWD/workspace/successful_fixes.md` | project (shared) | FIX-N confirmed wins; `task:` + `tags:`. |
| `$PWD/workspace/rule_violations.md` | project (shared) | Per-project AI behavioral mistakes (cache misjudgment, skipped record-before-op, etc.); `task:` + `tags:`. |
| `$PWD/workspace/<task>/goal.md` | per-task | AI fills when user explicitly asks; otherwise reads only. |

The 4 ledgers are **shared across all tasks in this repo**. Add `task: <name>` to every new entry so future sessions can filter. `goal.md` is the only per-task file.

bitter_lessons vs rule_violations: **bitter_lessons** = project technical pitfalls (bs=32 OOMs on this card, torch-compile + flame incompat). **rule_violations** = AI behavioral mistakes (skipped dispatch, misjudged KV cache, didn't record before op). Don't confuse them.

Stop-gate: at end of each turn, either append a new ledger entry OR write `[no new ledger entries]` for that task. Silence = records negligence.
