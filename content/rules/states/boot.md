# BOOT state

Entry: first UserPromptSubmit of a session. Hook (`session_boot.sh`) creates `$PWD/.barry_workflow/state_<sid>.md` + `action_<sid>.md` if missing, with `current_status: BOOT`.

Main duties:
- Confirm state file exists. If hook failed, surface to user.
- Write `[BOOT_DONE @ ts]` to action_<sid>.md.
- Call `transition.sh BOOT_DONE` to advance to PREPARE.

State file format: hybrid markdown + YAML block — see `content/templates/state_template.md`.
