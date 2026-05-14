# recording

Record before acting. Every meaningful operation (file edit, long Bash, Agent spawn, config change) gets a one-line `[PLAN]` entry in `$PWD/.barry_workflow/action_<sid>.md` *before* the tool call. Confession without a file record = double violation.

Recording targets:

| File | Scope | Contents |
|------|-------|----------|
| `content/templates/global_rules/violation.md` (repo) → deployed to `~/.claude/rules/violation.md` | global | AI behavioral violations (W-XXX + tags). Write to repo path (no approval click). |
| `content/templates/global_rules/lessons.md` (repo) → deployed to `~/.claude/rules/lessons.md` | global | Cross-project AI behavior wisdom (L-XXX + tags). |
| `$PWD/workspace/<task>/attempts_ledger.md` | project | ATT-N cross-turn intent log. |
| `$PWD/workspace/<task>/bitter_lessons.md` | project | Project-technical pitfalls (config combos that break, library incompatibilities, hardware quirks). |
| `$PWD/workspace/<task>/successful_fixes.md` | project | FIX-N confirmed wins. |
| `$PWD/workspace/<task>/rule_violations.md` | project | Per-project AI behavioral mistakes (KV-cache misjudgment, skipped record-before-op, etc.). |
| `$PWD/workspace/<task>/goal.md` | project | User-controlled. main reads only. |

bitter_lessons vs rule_violations: **bitter_lessons** = project technical pitfalls (bs=32 OOMs on this card, torch-compile + flame incompat). **rule_violations** = AI behavioral mistakes (skipped dispatch, misjudged KV cache, didn't record before op). Don't confuse them.

Stop-gate: at end of each turn, either append a new ledger entry OR write `[no new ledger entries]` for that task. Silence = records negligence.
