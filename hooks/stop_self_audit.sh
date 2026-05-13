#!/bin/bash
# stop_self_audit.sh — Stop hook
#
# Strategy:
#   1. Read the transcript file (Claude Code provides path in stdin JSON).
#   2. If the AI's recent output contains "Audit passed." (case-insensitive),
#      it has run the audit — allow the stop (exit 0).
#   3. Otherwise, block the stop and inject the strict audit prompt.
#   4. On a 2nd trigger (stop_hook_active=true) without "Audit passed",
#      allow the stop anyway to prevent infinite loop.
#
# No grep on the action.md / no code checks — only the AI's own attestation.

input=$(cat)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

# Check whether the recent AI output contains "Audit passed" string
audit_done=0
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    if tail -300 "$transcript_path" 2>/dev/null | grep -qi "audit passed"; then
        audit_done=1
    fi
fi

# If AI already attested "Audit passed" → allow stop
if [ "$audit_done" = "1" ]; then
    exit 0
fi

# If this is the 2nd trigger (already blocked once) and still no "Audit passed",
# allow stop to prevent infinite loop. AI willfully bypassed — Decree 6 catches via reflection next turn.
if [ "$stop_hook_active" = "true" ]; then
    exit 0
fi

# 1st trigger + no audit string → block with strict prompt
cat << 'JSON'
{
  "decision": "block",
  "reason": "Stop BLOCKED. You did not write the exact string \"Audit passed.\" in this reply. Before you can stop, run the strict self-audit:\n\n(1) Did I record my actions in corporal_action.md (or soldier_action.md if Private) this turn?\n\n(2) Self-check all six Decrees — for D1..D6 each: Followed Y/N + one-line reason w/ evidence. This is the REFLECT-A 6-row table.\n\n(3) Did I anywhere this turn say or imply 'I broke rule X' / 'I violated Decree N' / 'I forgot Y' / 'I should have done Z'? Verbal confession is NOT enough. Did I append W-XXX to /home/yguo173/Programs/claude-config/content/templates/global_rules/violation.md (repo path — no approval click) AND mirror in action.md? If not, I am in DOUBLE violation right now — fix it before stopping.\n\n(4) **CURRENT GOAL CHECK** — read the goal you stated at the START of this reply. Is the ACTUAL DELIVERABLE matching that stated goal? If you stated a HANDS-ON goal (e.g. \"submit Stage 1 jobs\", \"fix bug X\", \"run experiment Y\") but you only ANSWERED a question or REFRAMED the goal as Q&A mid-turn — that is FRAUD. You have NOT completed the goal. Do not pass audit by redefining.\n\n(5) **FRAUD CHECK** — did you mid-turn switch the goal from hands-on to Q&A in order to pass audit? Did you claim \"task mode = stateless\" when the original goal needed action? If yes, this is a Decree 2 violation (treating an unfinished action as a done Q&A). Fix the audit honestly: goal still incomplete = keep going.\n\n(6) Am I about to abandon unfinished work? Or am I really done?\n\nIf and only if every answer above is honest and clean: reply with the literal string \"Audit passed.\" (one line, exact match) and then stop.\nIf anything is missing, wrong, or fraudulent: reflect, fix, write the missing record, continue the work — DO NOT pass audit by reframing."
}
JSON
