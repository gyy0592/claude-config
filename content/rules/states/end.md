# END — session close

You are in END. RECORDING already wrote all ledger entries. END's sole job is the final user-facing summary + closing markers.

## Pipeline (do these in order)

### Step 1 — Final summary to user

SendMessage with:
- **Deliverable list**: which files / artifacts / data points landed
- **Outstanding caveats**: known limits, untested branches, deferred items
- **Suggested follow-ups**: what user might want next session

Format: concise, evidence-backed (cite specific files / line numbers / metrics).

### Step 2 — Action log close marker

Append final marker to action.md:

```
[END_DONE @ ts] complexity=<from BOOT_NOTE> deliverables=<N> ledgers_updated=<list-from-RECORDING>
```

The `ledgers_updated=<list>` field should mirror what the RECORDING `[RECORDING_SELF_CHECK]` block decided (e.g. `bitter_lessons+attempts` or `none`).

## Allowed
- Read / Bash(`ls`, `cat`, `head`, `tail`, `grep`)
- SendMessage final summary to user
- Append final `[END_DONE @ ts]` marker to action.md

## Forbidden
- New ledger writes (RECORDING already did them; if you missed something there, transition back via `BACK_TO_LOOP` then re-enter RECORDING — don't write from END)
- Starting new execution
- Spawning agents
- Mutating project source files
- Modifying `~/.claude/rules/*` directly

## Closing criteria — ALL must be true

- [ ] Final summary sent to user
- [ ] `[END_DONE @ ts]` marker written to action.md
- [ ] No half-finished work in action.md

## Re-entry

There is **no transition.sh out of END** — END is terminal for this session.

The next user prompt creates a new `<sid>` (BOOT state). P17 cross-session inherit copies `cache_hit_map` from this session forward automatically. Optional escape: env var `BARRY_FRESH_SESSION=1` skips inherit.
