# END — session close

You are in END. Task complete or paused. Archive only — no new execution.

## Pipeline (do these in order)

### Step 1 — Final summary to user

SendMessage with:
- **Deliverable list**: which files / artifacts / data points landed
- **Outstanding caveats**: known limits, untested branches, deferred items
- **Suggested follow-ups**: what user might want next session

Format: concise, evidence-backed (cite specific files / line numbers / metrics).

### Step 2 — Update project ledgers

Append to `$PWD/workspace/<task>/`:

| ledger | when to write |
|---|---|
| `attempts_ledger.md` | new attempt made this session (ATT-N entry with what was tried) |
| `successful_fixes.md` | a fix actually landed + verified (FIX-N entry with before/after) |
| `bitter_lessons.md` | discovered a non-obvious project pitfall (config combo / lib incompat / hardware quirk) |
| `rule_violations.md` | AI behavioral error caught this session (cache misjudgment, skipped record-before-op, etc.) |

If nothing applies, write `[no new ledger entries]` to action.md.

### Step 3 — Update global ledgers (when applicable)

Write to **repo path** (not `~/.claude/rules/` directly — that triggers approval prompt):

| ledger | content |
|---|---|
| `content/templates/global_rules/lessons.md` | L-N entry — cross-project AI behavior wisdom (e.g. "user prefers minimal-edits"), include `tags:` line |
| `content/templates/global_rules/violation.md` | W-N entry — AI rule violation crossing projects, include `tags:` |

User will `bash set_claude.sh` to sync to `~/.claude/rules/`.

### Step 4 — Action log close

Append final marker to action.md:

```
[END_DONE @ ts] complexity=<from BOOT_NOTE> deliverables=<N> ledgers_updated=<list>
```

## Allowed
- Read / Bash(`ls`, `cat`, `head`, `tail`, `grep`)
- Append (not overwrite) to ledger files under `workspace/<task>/`
- Write to global ledger via repo path `content/templates/global_rules/*.md`
- SendMessage final summary to user

## Forbidden
- Starting new execution
- Spawning execution agents
- Mutating project source files
- Modifying `~/.claude/rules/*` directly (use repo path instead)

## Closing criteria — ALL must be true

- [ ] Final summary sent to user
- [ ] Ledger entries written (or `[no new ledger entries]`)
- [ ] No half-finished work in action.md
- [ ] `[END_DONE @ ts]` marker written

## Re-entry

There is **no transition.sh out of END** — END is terminal for this session.

The next user prompt creates a new `<sid>` (BOOT state). P17 cross-session inherit copies `cache_hit_map` from this session forward automatically. Optional escape: env var `BARRY_FRESH_SESSION=1` skips inherit.
