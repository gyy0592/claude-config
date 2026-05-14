# p3 — dispatch

Trigger (any one): plan to Read > 1 file this turn / WebSearch / non-trivial code change / long-running command.

Required form:
```
Agent(subagent_type=<best fit>, run_in_background=true, prompt=...)
```
`run_in_background=true` is mandatory — even for short tasks. Foreground Agent calls block the main thread and forfeit the rebuttal protocol.

Subagent rules at `subagent_rules.md` are auto-injected into spawned subagents' prompts (P2 router hook handles this); the main thread does not need to copy them.

Monitor cadence: for any bg job whose wall-time may exceed 5 min, call `Monitor(bash_id=...)` every 10–15 min until it completes. Skipping monitoring on a long-running bg job = dereliction.

Cross-session jobs (queued past the current Claude session) use `CronCreate`, not `Agent`.
