#!/usr/bin/env bash
# inject_router.sh — slim router injection (~1.5 KB), v4 P2 replacement for inject_decrees.sh.
# Triggered by UserPromptSubmit; emits a short JSON envelope steering main to the
# right ~/.claude/rules/*.md file by symptom. Does NOT recite policies inline.
set -euo pipefail

cat <<'EOF'
[ROUTER] When you hit any of the triggers below, Read the matching ~/.claude/rules/ file. Do not pre-Read everything — load lazily.

| Trigger | File |
|---|---|
| self-reference / address user | p1_identity.md |
| writing [INFERENCE] or [ASSUMPTION] | p2_facts_first.md |
| Read >1 file / WebSearch / code change | p3_dispatch.md |
| edit / write / long Bash | p4_recording.md |
| start of turn flow / 4-step + REFLECT-A 6-row | p6_workflow.md |
| just spawned a subagent (auto-injected too) | subagent_rules.md |
| FSM state transition | fsm.md |
| suspected rule violation | violation.md (auto-loaded) |
| precedent / past wisdom | lessons.md (auto-loaded) |
| unsure which applies | index.md |

Three meta-rules (always on):
1. Dispatch — >1 file / WebSearch / code change ⇒ Agent(run_in_background=true).
2. Reflect — every reply opens with [BOARD_READ] + 4-module reflection in action_<sid>.md.
3. Monitor — long bg jobs need Monitor() every 10–15 min.

FSM: BOOT → PREPARE → REFLECT ↔ EXECUTE_LOOP. transition.sh <event> on each edge.
3-failure stop: after 3 autonomous-loop failures, stop + report (override: $PWD/CLAUDE.md AUTH keywords).
EOF
