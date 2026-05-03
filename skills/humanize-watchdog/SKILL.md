---
name: humanize-watchdog
user_invocable: true
description: "Spawn a /loop 30m task that monitors the active humanize RLCR loop and any background shells launched in this session. Use ONLY when the user explicitly invokes it — e.g. '/humanize-watchdog', 'start humanize watchdog', 'monitor my humanize loop'. The watchdog checks every 30 minutes whether the RLCR loop is still progressing and whether any background shells in /tmp/claude-bg.log are stuck. It self-terminates when the humanize loop ends. Never trigger automatically; never run without an active humanize RLCR loop."
---

# Humanize Watchdog

## Why this skill exists

The user runs `/humanize:start-rlcr-loop` for long autonomous coding sessions. During those sessions, background bash shells (started with `run_in_background: true`) sometimes hang — a subprocess deadlocks, a network call stalls, a child agent crashes silently. Hung shells block the user's external automation gate (the gate that says "Claude is done AND no bg work pending → next pipeline step"). Without a watchdog, a single zombie shell freezes the entire pipeline.

This skill installs a 30-minute liveness sweep that runs **alongside** the humanize loop without disturbing it. The sweep is a separate scheduled task, not part of the RLCR control flow, so it cannot corrupt loop state.

## How invocation works

When the user invokes this skill, do exactly the following — no other actions, no extra prose:

1. **Verify an active humanize loop exists.** Run:
   ```bash
   ls -dt "$PWD/.humanize/rlcr"/*/state.md "$PWD/.humanize/rlcr"/*/methodology-analysis-state.md "$PWD/.humanize/rlcr"/*/finalize-state.md 2>/dev/null | head -1
   ```
   The base path `$PWD/.humanize/rlcr` and the three state-file names are the canonical activity markers used by `scripts/cancel-rlcr-loop.sh:103-106`. If the command prints nothing, no loop is active — tell the user "No active RLCR loop in $PWD/.humanize/rlcr — watchdog not started" and stop.

2. **Schedule the watchdog.** Use the `/loop` slash command (bundled skill). Pass the watchdog prompt below verbatim, prefixed with the literal tag `[WATCHDOG]` so future iterations can find this task in `CronList`:

   ```
   /loop 30m [WATCHDOG] Read the watchdog body in ~/Programs/claude-config/skills/humanize-watchdog/SKILL.md (section "Watchdog iteration body") and execute it. Do not load any other skill. One-line status output only.
   ```

   The reason for the indirection: the actual logic lives in this file, so the user can edit and tune the watchdog without rescheduling.

3. **Confirm to the user with one line:** `Watchdog scheduled: 30m interval, active loop = <path-from-step-1>`. Nothing else.

## Watchdog iteration body

When fired by `/loop`, do the following minimum-disruption sweep. Total output budget: one terminal line. Do not read any RLCR state file beyond the existence check below — those files are owned by the humanize loop and reading them while the loop is mid-write can race.

### Step A — humanize loop liveness

```bash
LOOP_BASE="$PWD/.humanize/rlcr"
ACTIVE=$(ls -dt "$LOOP_BASE"/*/state.md "$LOOP_BASE"/*/methodology-analysis-state.md "$LOOP_BASE"/*/finalize-state.md 2>/dev/null | head -1)
```

If `$ACTIVE` is empty, the humanize loop has finished or been cancelled. The watchdog's job is over:

1. Call `CronList` to enumerate scheduled tasks.
2. Find the entry whose prompt starts with `[WATCHDOG]`.
3. Call `CronDelete <task_id>` to remove the watchdog itself. (This is the only way to self-terminate; `/loop` has no in-prompt self-cancel — see https://code.claude.com/docs/en/scheduled-tasks .)
4. Print one line: `Watchdog: humanize loop ended, watchdog removed.` Exit.

If `$ACTIVE` is non-empty, capture its mtime as `LOOP_TS=$(stat -c %Y "$ACTIVE")` and continue.

### Step B — background shell liveness

Read the last 50 lines of the bg shell log (this log is populated by the global PostToolUse hook — see the `humanize-watchdog` companion settings.json snippet in this directory if it has not been set up yet):

```bash
test -f /tmp/claude-bg.log && tail -50 /tmp/claude-bg.log
```

For each unique shell ID in those lines:

1. Call `BashOutput(<shell_id>)` to fetch any new stdout since last poll. Most healthy shells will return new lines or an empty string with the shell still alive.
2. Compare the size of the cumulative output against `/tmp/claude-watchdog-state.json` (a small JSON file owned by this skill, mapping `shell_id → {last_size, last_grow_ts}`). If `last_grow_ts` is older than 30 minutes AND the shell is still reported as running, treat the shell as **stuck**.
3. For stuck shells: do NOT auto-kill on the first detection. Append `<ts> stuck shell_id=<id>` to `/tmp/claude-watchdog-stuck.log`. Only on the **second consecutive** detection (i.e., the next 30-minute tick still finds the same shell stuck) call `KillShell(<shell_id>)`. The two-strike rule prevents killing a shell that is legitimately doing slow work like a long compile.

### Step C — humanize loop progress check

Compare `$LOOP_TS` (captured in Step A) to its value from the previous tick (stored in `/tmp/claude-watchdog-state.json` under key `humanize_loop_mtime`). If the value has not changed in **two consecutive ticks** (i.e., 60 minutes of zero state-file activity), the humanize loop itself may be wedged. Do not touch its files. Append one line to `/tmp/claude-watchdog-stuck.log`:

```
<ts> humanize loop unchanged 60min, active=<basename of $ACTIVE>
```

This file is the user's signal — they decide whether to intervene.

### Step D — one-line output

Emit exactly one line to the conversation, of the form:

```
Watchdog tick: humanize=<active|stuck60m>, bg_shells=<N alive, M stuck>, killed=<K>.
```

No other prose. No tool-use justification. No reading of unrelated files. The watchdog's value is in being silent when everything is fine.

## Why these specific design choices

- **Indirection through this file** (rather than inlining all logic into the `/loop` prompt) lets the user edit thresholds without re-running `/loop`. The next 30-minute tick re-reads the body. The cost is one extra file read per tick — negligible.

- **No state-file writes by the watchdog into `.humanize/rlcr/`.** The humanize loop assumes exclusive writer access to those paths; any concurrent writer would corrupt RLCR coordination. The watchdog only `stat`s and reads.

- **Two-strike kill rule** balances two failure modes: a single false-positive (kill a slow-but-progressing shell) wastes work; a single false-negative (refuse to kill a true zombie) blocks the gate. Two strikes at 30-minute spacing means a shell must produce zero output for ~60 minutes before being killed, which is well above any reasonable busy-loop timeout.

- **Self-termination via CronDelete** is the only documented mechanism. Per https://code.claude.com/docs/en/scheduled-tasks the `/loop` slash command has no in-prompt cancel. Tasks scheduled by Claude (as opposed to interactive `/loop`) are not affected by Esc. CronList → match the `[WATCHDOG]` prefix → CronDelete is the canonical pattern.

- **The seven-day expiry** in `/loop` (also from the same doc) is a safety net: if the watchdog ever fails to self-terminate, it expires automatically.

## Companion: PostToolUse hook for /tmp/claude-bg.log

The watchdog reads `/tmp/claude-bg.log`. That log is populated only if the user has the following hook configured in `~/.claude/settings.json`. If the file does not exist when the watchdog first runs, log a single warning:

```
Watchdog: /tmp/claude-bg.log not found — install PostToolUse(Bash) hook (see humanize-watchdog/SKILL.md).
```

and continue with humanize-loop liveness only.

The hook (paste into `~/.claude/settings.json`):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "jq -c 'select(.tool_input.run_in_background==true) | {ts: now, id: .tool_use_id, resp: .tool_response, cmd: .tool_input.command}' >> /tmp/claude-bg.log"
        }]
      }
    ]
  }
}
```

This hook is harness-enforced — every background Bash launch is recorded. Reference: https://code.claude.com/docs/en/hooks-guide .

## How to stop the watchdog manually

Three options, in order of preference:

1. Let it self-terminate when the humanize loop ends (default behavior).
2. Tell Claude in natural language: `cancel the humanize watchdog`. Claude will `CronList`, match the `[WATCHDOG]` prefix, and `CronDelete`.
3. Wait seven days for automatic expiry.
