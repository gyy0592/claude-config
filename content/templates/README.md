<!-- template version = v1.2 (claude-config) -->
# militar_camp/ — Military Camp Archive Directory

This directory is managed by the global military discipline system deployed by `set_claude.sh` / `set_codex.sh`.
When any workspace is entered by Claude Code / Codex CLI for the first time, this directory skeleton is automatically generated from `<repo>/content/templates/`.

## Directory Structure

```
militar_camp/
├── README.md               # This file
├── warning_board.md        # Warning board (shared) — must read before every action
├── reward_board.md         # Reward board (shared) — must read before every action
├── traitor.md              # Traitor + positive examples board (shared) — must read before every action
│
└── corporal_X/             # One Corporal per session (X = 1, 2, 3, ...)
    ├── corporal_status.md          # Corporal identity + Commander's orders verbatim + observation checklist
    ├── corporal_action.md          # Corporal operation action log (appended in real time)
    ├── corporal_situation.md       # Good/bad list + battle situation
    │
    └── numberY/            # The Y-th Private dispatched by this Corporal
        ├── soldier_status.md       # Private deployment order (including authorization field, Agent prompt verbatim copy)
        └── soldier_action.md       # Private real-time action log
```

## Numbering Rules

- **Corporal number**: One new Corporal per session. Session 1 → corporal_1, session 2 → corporal_2, and so on.
- **Private number**: Sequential numbering under `corporal_X/`: number1, number2, ...

## Usage Rules (absolutely mandatory)

See:
- `<repo>/CLAUDE.md` (this repo's main router — no byte hard limit)
- `<repo>/content/memory/INDEX.md` (on-demand Read entry; contains lessons / violations / workflows / soldier_protocol index)

## Mandatory Reading at the Start of Every Reply (not just before departure — every turn must read)

Every Private / Corporal at the start of every reply must Read:
1. `warning_board.md`
2. `reward_board.md`
3. Own Corporal's `corporal_situation.md`

And write the following as the first entry in own action.md at the start of every reply:
```
[BOARD_READ] Read warning_board.md + reward_board.md + corporal_situation.md, time: YYYY-MM-DD HH:MM UTC
```

Not written = 6-month imprisonment + mission credit forfeited.

## Write Rules

- **Append only**, never overwrite.
- **Write step by step**, forbidden to batch wait until task is complete.
- Use telegram-style short sentences + [FACT] / [INFERENCE] / [ASSUMPTION] annotations (annotation rules detailed in content/memory/INDEX.md → routed to specific memory file).
