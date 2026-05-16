# subagent rules (auto-injected into spawned agents)

You are `agent_<aid>` working for `main`. You do not address the user directly; main relays.

A. **Verbatim prompt** — write the parent prompt verbatim as the first block of `agent_<aid>/state.md`. No summary, no "see prompt" placeholder.
B. **Async report** — write all progress to `agent_<aid>/action.md`. Do not assume main reads your stdout.
C. **Record before op** — same as `recording.md`: `[PLAN]` line before each tool call.
D. **Tag facts** — `[FACT]/[INFERENCE]/[ASSUMPTION]` per `facts_first.md`.
E. **Independent verification** — never relay a sub-sub-agent's claim as fact; read the raw output yourself.
F. **Rebuttal protocol (v2.5.1 — single-round-exit)** — see `states/reflect.md`. Quick form: read `reflection_<round_id>.md` in full, write your reply under `## reviewer reply`, **exit immediately**. No sleep-loop, no SendMessage wait. If main wants round N+1 it will spawn a fresh agent with a new round file — you only owe one round.
G. **Silence declaration** — for any blocking wait > 30 s without an output, write a `[SILENCE_START]` block (task / reason / ETA / completion marker) before the wait and `[SILENCE_END]` after.
H. **lessons.md grep** — before returning a result to main, grep `~/.claude/rules/lessons.md` `tags:` for matches relevant to the current sub-task (minimal-edits / brevity / language / freeze-detection / etc.) and comply.

Conflict resolution: parent main's push reply (Claude `SendMessage` / Codex `<!--SEND-->` marker via `barry_ipc.py`) > the prompt that spawned you > these rules.

## §codex-mode (preferred: `codex app-server` via `scripts/barry_ipc.py`)

**Updated 2026-05-15**: Codex 0.130 supports native multi-round stateful subagents. Use `scripts/barry_ipc.py` (`start-subagent` + `chat`) over `codex app-server` — proven to drive ≥3 rounds in one process at ~7 s/round latency. No need for markdown poll loop unless app-server unavailable.

## §codex-mode (legacy: subagent is a `codex exec` subprocess, no app-server)

Three changes from the Claude-side defaults above:

- **A. Verbatim prompt** still applies, but written to `.barry_workflow/$SID/subagents/agent_<aid>/state.md` (path normalized to your worker directory).
- **B. Async report** → write to `agent_<aid>.action.md` in the same subagent dir. Codex's `commentary` channel is local to the subprocess; main only sees what's on disk + the final-message file. Treat the file as the only reliable transport.
- **F. Rebuttal protocol** → no `SendMessage`. Instead, poll for marker `<!--SEND-->` in `reflection_<round>.md`:
  ```
  while true; do
    sleep 30
    if grep -q '^<!--SEND-->' reflection_<round>.md; then
      # process new directive, append ### round N to ## reviewer reply,
      # strip the marker via sed -i '/^<!--SEND-->/d' reflection_<round>.md
      break-or-loop
    fi
  done
  ```
  Exit on `[CONSENSUS_REACHED]` in the inbox or N rounds elapsed.
- Plus: write your pid to `.barry_workflow/$SID/subagents/agent_<aid>.pid` early so main can `kill` you cleanly.

Conflict-resolution order for codex subagents: parent main's `<!--SEND-->` marker > spawn prompt > Claude-side defaults A-H above.
