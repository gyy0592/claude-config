<!-- state_enforce.sh warning template. {STATUS} / {DETAIL} are sed-substituted. -->
<!-- One {{KEY}} → {{VALUE}} pair per case; hook picks the right one before emit. -->

# state_enforce warning catalog

key: REFLECT_EDIT
template: "{TOOL} not allowed in REFLECT — defer mutations until 'transition.sh REFLECT_DONE'."

key: REFLECT_BASH_MUTATOR
template: "Bash mutator '{CMD}' — defer until REFLECT_DONE."

key: PREPARE_EDIT
template: "{TOOL} discouraged in PREPARE — finish PREPARE_DONE before executing."

key: BOOT_BASH_BAD
template: "Bash '{CMD}' — BOOT allows only Read/Glob/Grep + transition.sh/ls/cat."

key: BOOT_TOOL_BAD
template: "{TOOL} not allowed in BOOT; only Read/Glob/Grep + transition.sh/ls/cat."

# Output format: "[state_enforce] {STATUS} state — <template-substituted>"
