# dispatch

Trigger (any one): plan to Read > 1 file this turn / WebSearch / non-trivial code change / long-running command.

Required form:
```
Agent(subagent_type=<best fit>, run_in_background=true, prompt=...)
```
`run_in_background=true` is mandatory — even for short tasks. Foreground Agent calls block the main thread and forfeit the rebuttal protocol.

Subagent rules at `subagent_rules.md` are auto-injected into spawned subagents' prompts (P2 router hook handles this); the main thread does not need to copy them.

Cross-session jobs (queued past the current Claude session) use `CronCreate`, not `Agent`.

(Monitor cadence for long bg jobs — scenario-specific — moves to `patches/long_monitor.md` in v2.1 batch 2.)
