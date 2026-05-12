# Hook System Research Notes (kept across reset)

## Hook Trigger Lifecycles (verified via WebSearch on 2026-05-12)

Three cadences:
| Cadence | Hooks |
|---------|-------|
| Once per session | `SessionStart`, `SessionEnd` |
| Once per turn | `UserPromptSubmit`, `Stop`, `StopFailure` |
| Every tool call | `PreToolUse`, `PostToolUse` |
| Subagent | `SubagentStop` (cannot inject to parent — no additionalContext) |
| Other | `Notification`, `PreCompact` |

## Key Findings

1. **UserPromptSubmit fires on CronCreate iterations** (cron firing = UserPromptSubmit + Stop hooks).
   Source: https://code.claude.com/docs/en/scheduled-tasks
   Source: https://agentfactory.panaversity.org/docs/General-Agents-Foundations/general-agents/scheduled-tasks-cron

2. **Subagents DO NOT inherit CLAUDE.md or project-level instructions.**
   Source: https://code.claude.com/docs/en/sub-agents
   - Only way to pass rules: main thread manually prepends content to dispatch prompt.
   - No OnAgentSpawn hook exists (open feature request: github.com/anthropics/claude-code/issues/49106).

3. **SubagentStop cannot inject to parent (main) context** — does not support additionalContext.
   - Workaround: PostToolUse matcher=Agent fires after agent returns to main thread.
   Source: https://github.com/anthropics/claude-code/issues/5812

4. **PreToolUse can modify tool input** — can intercept Agent tool call and inject rules into the `prompt` parameter before subagent starts.
   Source: https://code.claude.com/docs/en/hooks

5. **Hook output cap: 10,000 chars** — larger output saved to file with preview.

6. **Custom subagents (~/.claude/agents/*.md)**: frontmatter can declare hooks scoped to that subagent's lifecycle.
   Source: https://code.claude.com/docs/en/sub-agents

## Hook Strategy Options (research output, not yet decided)

| Goal | Hook | Notes |
|------|------|-------|
| Inject Decrees to main thread per turn | `UserPromptSubmit` | Covers user + cron |
| Inject Decrees after long agent chain | `PostToolUse` matcher=Agent | Fires when agent returns; injects into main thread |
| Inject Decrees into subagent's init | `PreToolUse` matcher=Agent (modify prompt) | OR define custom subagent in ~/.claude/agents/private.md |
| Cap output at 10KB | — | Current full Decrees + brute repeat = ~3KB, safe |

## Adaptive Injection Idea (size-based)

Hook stdin contains `transcript_path` JSON field. Script can `wc -c` it and inject:
- < 50 KB: minimal (brute repeat only)
- 50-200 KB: medium (brute + summary)
- > 200 KB: full (Decrees + double brute repeat)

NOT YET IMPLEMENTED.

## Prompt Reinforcement (4-item kit) — currently NOT in hook
Lives in content/CLAUDE.md §3.5 + memory/soldier_protocol.md.
4 items: observable variables / monitoring cadence / reflection requirements / completion definition.
Required before dispatch, but currently dead rule because hook doesn't inject it and subagents don't read CLAUDE.md.
