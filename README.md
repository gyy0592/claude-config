# claude-config

Personal Claude Code configuration for migration.

## Contents

- `settings.json` — Plugin subscriptions (38 skills auto-downloaded on launch)
- `skills/` — Custom global skills (manually maintained)

## Plugin skills (auto-installed via settings.json)

| Plugin | Skills |
|---|---|
| `humanize@humania` | ask-codex, humanize, humanize-gen-plan, humanize-rlcr |
| `document-skills@anthropic-agent-skills` | pdf, docx, pptx, xlsx, frontend-design, canvas-design, claude-api, algorithmic-art, brand-guidelines, doc-coauthoring, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing |
| `claude-api@anthropic-agent-skills` | same 17 skills, claude-api variant |

## Custom global skills

| Skill | Trigger | Description |
|---|---|---|
| `gen-report` | `/gen-report` | Concise experiment report |
| `gen-report-detailed` | `/gen-report-detailed` | Full 13-section detailed report |

## Migration

```bash
git clone https://github.com/gyy0592/claude-config.git
cp claude-config/settings.json ~/.claude/settings.json
mkdir -p ~/.claude/skills
cp -r claude-config/skills/* ~/.claude/skills/
```

Restart Claude Code — plugin skills install automatically, custom skills are immediately available.
