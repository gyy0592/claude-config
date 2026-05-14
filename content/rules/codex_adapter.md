# codex adapter (v4 P10)

This document maps the Claude-Code-specific tools used by v4 to their Codex
equivalents (or documented fallbacks where no equivalent exists). The core
mechanism — state machine, KV-cache self-report, rebuttal protocol — is
tool-agnostic; only the transport layer differs.

## Tool mapping

| Claude Code | Codex | Status | Adapter |
|---|---|---|---|
| `Read` / `Edit` / `Write` / `Glob` / `Grep` | same | ✅ identical | none |
| `Bash` (incl. `run_in_background=true`) | `Bash` / `apply_patch` | ✅ identical | none |
| `Agent(run_in_background=true, ...)` | subagent spawn (varies by host) | ⚠ wrapper | see `spawn_subagent` below |
| `SendMessage(to=<agent_id>, message=...)` | **no native equivalent** | ⚠ fallback | see "Markdown poll loop" below |
| `Monitor(bash_id=...)` | `tail -f` / `BashOutput` | ⚠ wrapper | see `poll_bg_output` below |
| `TaskCreate` / `TaskList` / `TaskStop` | none | ⚠ file-state | use `workspace/<task>/attempts_ledger.md` |
| `KillBash` | `kill <pid>` | ⚠ pid lookup | parse `claude-bg.log` for pid |
| `/goal` (slash command) | none | ❌ no native | autonomous-3-failure rule from p6_workflow.md M6 is the only stop signal |
| `~/.claude/rules/*.md` auto-load | `~/.codex/rules/*.md` | ⚠ deploy | extend `set_codex.sh` to mirror `set_claude.sh` rules-deploy block |
| `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `Stop` hooks | `~/.codex/config.toml` hooks section | ✅ different syntax, same semantics | translate JSON-envelope hooks to toml |

## Markdown poll loop (SendMessage fallback)

```
main (driver)                          subagent (responder)
────────────                          ──────────────────
1. Write reflection_<round>.md
   with `## main's questions`.
                       ↓
2. Spawn subagent (Codex bg).         3. Read reflection_<round>.md.
                                      4. Write `## reviewer reply`.
                                      5. Enter poll loop:
                                         while true; do
                                             sleep 30
                                             # check inbox marker
                                             if grep -q '^<!--SEND-->'
                                                 reflection_<round>.md; then
                                                 # process new directive
                                             fi
                                         done
                       ↓
6. main appends `<!--SEND-->\n<msg>`
   to reflection_<round>.md.
                                      7. Detect marker, append `### round N`,
                                         remove the marker line.
                                      8. Back to sleep.
... repeat until `<!--SEND-->\n[CONSENSUS_REACHED]\n<actions>` arrives ...
9. main strips inbox markers, writes
   final consensus block, calls
   transition.sh REFLECT_DONE,
   kills subagent.
```

vs Claude SendMessage (async, push-driven, no polling overhead):
- 30-second polling latency per round → N=5 rebuttal adds ~5 × 30s = 2.5 min
  of pure wait time vs Claude's near-instant SendMessage wake.
- File-locking concern: append-only markers + sed strip keep races rare;
  add `flock` if both sides actually conflict in practice.

## `/goal` fallback

Codex has no session-scoped goal slash command. v4 workflow degrades to:
1. user writes the goal verbatim into `workspace/<task>/goal.md` at task start.
2. main's REFLECT (post-task) sub-agent verifies `goal.md` criteria against
   delivered artefacts before allowing `transition.sh REFLECT_DONE`.
3. autonomous-3-failure rule (`p6_workflow.md` M6) is the only stop-gate.

Loss vs `/goal`: no runtime LLM evaluator forcing continuation. Trade-off
acceptable; user oversight via `goal.md` is the substitute discipline.

## Deferred (not in P10 scope)

- Actual Codex test run end-to-end (needs Codex CLI environment + a port of
  set_codex.sh's hook registration syntax).
- pid-based KillBash adapter (depends on Codex bg-job model).
- Performance benchmarking (Claude SendMessage latency vs Codex poll-loop).

Revisit after P8 demo run lands and we have a real workload to port.
