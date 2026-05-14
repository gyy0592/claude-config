# BOOT — session boot

You are in BOOT. This state runs once at the start of each session. You orient yourself, read prior context, and classify task complexity. <b>No mutations allowed</b>.

## Pipeline (do these in order)

### Step 1 — Confirm state file
```
cat $PWD/.barry_workflow/<sid>/state.md
```
Expect `current_status: BOOT`. If file missing, the session_boot.sh hook failed; surface to user before continuing.

### Step 2 — Read project context

In this order, Read whichever exist:

1. `$PWD/CLAUDE.md` — project-level instructions
2. `$PWD/workspace/<task>/goal.md` — user-written goal for this task
3. `$PWD/workspace/bitter_lessons.md` (shared across tasks; tail 50 lines, then grep `task: <current>` + relevant `tags:` for cross-task hits)
4. `$PWD/workspace/successful_fixes.md` (shared; tail 30 lines + same filter as above)
5. `$PWD/workspace/rule_violations.md` (shared; grep prior AI errors that may recur)

### Step 3 — Read global wisdom (already auto-loaded but skim)

- `~/.claude/rules/lessons.md` — grep `tags:` for terms relevant to current task
- `~/.claude/rules/violation.md` — grep for past AI behavior pitfalls in similar task types

### Step 4 — Classify task complexity

Write a 1-line marker to action.md:

```
[BOOT_NOTE complexity=<class> reason=<short>]
```

Valid classes (drives which patches to apply in PREPARE):

| class | when |
|---|---|
| `simple` | typo / 1-line / single Read / no test needed |
| `normal` | focused multi-file work, < 1 hr expected |
| `long_monitor` | sbatch / training / 2hr+ bg jobs |
| `bug_debug` | known error, reproduce-fix-verify |
| `perf_debug` | "slow" / "low util" / optimization |
| `explore` | "investigate" / "research" / no clear solution |

### Step 5 — Confirm session continuity

If state.md YAML has `inherited_from: <old_sid>`:
- Read `$PWD/.barry_workflow/<old_sid>/action.md` (tail 30 lines)
- Note absorbed `cache_hit_map` rows in the new state.md

## Allowed
- Read / Glob / Grep
- Bash: `transition.sh`, `ls`, `cat`, `pwd`, `head`, `tail`, `wc`, `grep` only
- SendMessage to user (status updates / clarification questions)

## Forbidden
- Edit / Write / NotebookEdit on any file
- Bash mutators: `rm`, `mv`, `cp` (write side), `sed -i`, `>`, `>>`, `tee`
- Spawning subagents (`Agent` tool) — that's PREPARE+
- Starting long bg jobs
- WebSearch (defer to PREPARE where it has plan context)

## Completion criteria — ALL must be true before advancing

- [ ] state.md confirmed `current_status: BOOT`
- [ ] CLAUDE.md / goal.md Read (or confirmed absent)
- [ ] `[BOOT_NOTE complexity=<class>]` written to action.md
- [ ] inherited_from absorbed (if applicable)

## Advance

```
bash ~/.claude/hooks/transition.sh BOOT_DONE --reason="<short>"
```

→ Next state: PREPARE. The transition script will cat `states/prepare.md` so you immediately see the next pipeline.
