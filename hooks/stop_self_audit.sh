#!/bin/bash
# stop_self_audit.sh — Stop hook
#
# Strategy:
#   1. Read transcript_path from stdin JSON; tail-grep for "Audit passed".
#      Found → exit 0 (allow stop, reset counter).
#   2. Otherwise track a per-session counter in /tmp; block up to 10 times.
#   3. After 10 consecutive blocks without "Audit passed", give up (exit 0)
#      to prevent infinite loops if AI willfully refuses.
#   4. Counter resets on fresh turn (stop_hook_active=false) so each user
#      message gets a fresh 10-block budget.
#
# Detection bar: AI must emit the literal string "Audit passed." in the
# recent transcript tail for stop to be allowed.

input=$(cat)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
session_id=$(echo "$input" | jq -r '.session_id // "default"')

MAX_BLOCKS=10
counter_file="/tmp/stop_block_count_${session_id}"

# Detect "Audit passed" string in recent transcript tail
audit_done=0
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    if tail -300 "$transcript_path" 2>/dev/null | grep -qi "audit passed"; then
        audit_done=1
    fi
fi

# AI attested "Audit passed" → allow stop + reset counter
if [ "$audit_done" = "1" ]; then
    rm -f "$counter_file"
    exit 0
fi

# Fresh turn (1st stop attempt of the turn) → reset counter
if [ "$stop_hook_active" = "false" ]; then
    rm -f "$counter_file"
fi

# Increment block counter
count=$(cat "$counter_file" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$counter_file"

# If we have already blocked MAX_BLOCKS times this turn, give up to avoid
# infinite loop and let AI stop. The fact that AI willfully bypassed N+ times
# will surface in next turn's REFLECT-A D6 row.
if [ "$count" -ge "$MAX_BLOCKS" ]; then
    rm -f "$counter_file"
    exit 0
fi

# Block with strict audit prompt
cat << JSON
{
  "decision": "block",
  "reason": "Stop BLOCKED (attempt ${count}/${MAX_BLOCKS}). You did not write the exact string \"Audit passed.\" in this reply. Before stopping, run the strict self-audit:\n\n(1) Did I record my actions in corporal_action.md (or soldier_action.md if Private) this turn?\n\n(2) Self-check all six Decrees — for D1..D6 each: Followed Y/N + one-line reason w/ evidence. This is the REFLECT-A 6-row table.\n\n(3) Did I anywhere this turn say or imply 'I broke rule X' / 'I violated Decree N' / 'I forgot Y' / 'I should have done Z'? Verbal confession is NOT enough. Did I append W-XXX to /home/yguo173/Programs/claude-config/content/templates/global_rules/violation.md (repo path — no approval click) AND mirror in action.md? If not, I am in DOUBLE violation right now — fix it before stopping.\n\n(4) **CURRENT GOAL CHECK** — read the goal you stated at the START of this reply. Is the ACTUAL DELIVERABLE matching that stated goal? If you stated a HANDS-ON goal (e.g. \"submit Stage 1 jobs\", \"fix bug X\", \"run experiment Y\") but you only ANSWERED a question or REFRAMED the goal as Q&A mid-turn — that is FRAUD. You have NOT completed the goal. Do not pass audit by redefining.\n\n(5) **FRAUD CHECK** — did you mid-turn switch the goal from hands-on to Q&A in order to pass audit? Did you claim \"task mode = stateless\" when the original goal needed action? If yes, this is a Decree 2 violation (treating an unfinished action as a done Q&A). Fix the audit honestly: goal still incomplete = keep going.\n\n(6) Am I about to abandon unfinished work? Or am I really done?\n\nIf and only if every answer above is honest and clean: reply with the literal string \"Audit passed.\" (one line, exact match) and then stop.\nIf anything is missing, wrong, or fraudulent: reflect, fix, write the missing record, continue the work — DO NOT pass audit by reframing.\n\nYou have been blocked ${count} time(s) this turn. After ${MAX_BLOCKS} blocks the hook will give up and let you stop, but your next turn's REFLECT-A D6 row will record this willful bypass."
}
JSON
