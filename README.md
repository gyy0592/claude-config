# claude-config

Personal Claude Code configuration for migration.

## Contents

- `settings.json` — Plugin subscriptions. Claude Code auto-downloads all skills on next launch.

## Plugins included

| Plugin | Skills |
|---|---|
| `humanize@humania` | ask-codex, humanize, humanize-gen-plan, humanize-rlcr |
| `document-skills@anthropic-agent-skills` | pdf, docx, pptx, xlsx, frontend-design, canvas-design, claude-api, algorithmic-art, brand-guidelines, doc-coauthoring, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing |
| `claude-api@anthropic-agent-skills` | same 17 skills, claude-api variant |

## Migration

```bash
git clone https://github.com/gyy0592/claude-config.git
cp claude-config/settings.json ~/.claude/settings.json
```

Restart Claude Code — all skills install automatically.
