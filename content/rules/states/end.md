# END state

Terminal status for a session. Entered when EXECUTE_LOOP reports `--reason=done` and no further work is queued, or when the user explicitly closes the task.

Main duties at END:
- Append final ledger entry (or `[no new ledger entries]`) per `recording.md`.
- Confirm `state_<sid>.md` `current_status: END` and `stage_history` reflects the path taken.
- No transitions out of END within the same session.
