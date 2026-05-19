# CONVERSATION state

Entered via USER_JUMP_CONVERSATION event from any state.

## Purpose
Allows the user to have a direct discussion without triggering the full BOOT→PREPARE→REFLECT→EXECUTE pipeline. Useful when the user wants to ask questions, review output, or give feedback without starting a new task.

## Rules
- No goal.md required.
- No stop gate check (stop_state_audit.sh exempts this state).
- No EXECUTE_EXIT / RECORD_DONE required before session end.
- Respond directly. [PLAN]/[OBSERVE] pattern not required for conversational replies.

## Exit
- User gives clear task instruction → main announces switch → `RESET_TO_BOOT`
- User wants to resume prior EXECUTE_LOOP work → `BACK_TO_LOOP`
- User starts new session naturally → new sid, normal BOOT
