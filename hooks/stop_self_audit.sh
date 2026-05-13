#!/bin/bash
# stop_self_audit.sh — Stop hook
#
# On the FIRST stop attempt of each turn, blocks the stop and prompts the AI
# to self-audit against the Decrees. On the SECOND stop attempt (after the
# AI has already self-audited), lets the AI stop normally — this is how we
# prevent infinite loops, using Claude Code's `stop_hook_active` field.
#
# No grep / no code checks — pure prompt; trust the AI to self-judge.

input=$(cat)

# Second-time trigger? AI already self-audited — let it stop.
if [ "$(echo "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
    exit 0
fi

# First trigger — block with self-audit checklist
cat << 'JSON'
{
  "decision": "block",
  "reason": "Before you stop, run a self-audit (no shortcuts, use your own judgement):\n\n(1) Did I record my actions in corporal_action.md (or soldier_action.md if I am a Private) this turn?\n\n(2) Self-check all six Decrees — for each (D1 Identity / D2 Facts-First / D3 Dispatch+Monitor / D4 Recording / D5 Reading / D6 Workflow+Fix-loop) write a one-line evidence reason. This is the REFLECT-A 6-row table.\n\n(3) Did I anywhere this turn say or imply 'I broke rule X' / 'I violated Decree N' / 'I forgot Y' / 'I should have done Z'? If yes — verbal confession is NOT enough. Did I write the W-XXX entry to ~/.claude/rules/violation.md AND mirror it in action.md? If not, I am in DOUBLE violation right now. Fix it before stopping.\n\n(4) Am I actually done? Or am I about to abandon unfinished work?\n\nIf every answer is clean: reply with \"Audit passed.\" (one line) and stop.\nIf anything is missing or wrong: reflect on it, fix it, write the missing record, then stop."
}
JSON
