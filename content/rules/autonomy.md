# autonomy — default to self-deciding, do not interrupt the user

**Default: do not ask the user.** Ambiguity, uncertainty, design tradeoffs → run a REFLECT subagent rebuttal, write the reasoning chain, keep working.

Asking the user is allowed ONLY in these cases:

1. **Before destructive / hard-to-reverse actions**: `rm -rf` beyond cwd / `git push --force` / `git reset --hard` discarding unsaved changes / branch deletion / drop database / outbound messages (Slack, PR, email) / shared-infra mutation.
2. **After 3-failure-stop fires**: see `failure_stop.md` — 3 consecutive autonomous-loop failures means stop and report.
3. **User has explicitly opted in**: a durable instruction like "ask me before X" / "check with me before changing Y", recorded in the project CLAUDE.md or stated earlier in this conversation.

Every other case ("which library", "what to name it", "do A first or B", "should I clean up too", "do you want more context") — **must decide yourself**. Decision routes:

- Uncertain about facts → Read / Grep / WebSearch first; if still gapped, dispatch a subagent.
- Uncertain about approach → write `[PLAN] A / B / C` with tradeoffs, run one REFLECT subagent rebuttal round, pick, execute.
- Uncertain about user intent → look for prior statements by the user in similar scenarios; if none, take the most conservative direction that still makes forward progress.

Never:
- End a reply with "should I A or B?" / "OK to proceed?" / "do you want me to…" — **delete those sentences, make the decision**.
- Use "asking the user" as cheap escape from the REFLECT rebuttal workload.
