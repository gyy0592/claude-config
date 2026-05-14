---
id: P-004
created: 2026-05-14T00:00:00Z
source: human
scope: global
applies_to:
  state: [PREPARE, EXECUTE_LOOP]
  scenario: simple
  triggers:
    - intent: ["one-line edit", "rename", "typo", "small refactor", "single-file change", "quick fix"]
    - estimated_steps: "<= 3"
priority: 90
status: active
---

## what

Skip the pre-task REFLECT cycle for trivially-scoped tasks; keep the post-task REFLECT for verification. Trade pre-task dialectic overhead against time-to-completion when the change is genuinely small.

## why

- L-001 minimum-fix: gold-plating small tasks with a full REFLECT cycle inflates them into scope-creep.
- pre-task REFLECT N=5 + per-question rebuttal costs more than a 1-line edit deserves.

## how

Eligibility (ALL must hold):
- Edit count ≤ 1 file AND diff ≤ ~10 lines (estimated).
- No new dependency, no config change, no API surface change.
- No "this might break X" worry from user or main.

If eligible:
1. PREPARE → write `[SCENARIO=simple]` in action.md to record the choice.
2. Skip pre-task REFLECT. `transition.sh PREPARE_DONE --reason=simple-scenario` directly.
3. EXECUTE_LOOP: [PLAN] → edit → [OBSERVE] (mandatory). One iteration only — if it doesn't work on first try, escalate to bug_debug.md patch.
4. Post-task REFLECT is still mandatory: 1 round, verify the change does what was asked.

Escalation: any anomaly during EXECUTE_LOOP → drop simple_fast patch + apply bug_debug.md from next iteration.

## examples

User: "rename variable foo to bar in module x.py" → simple_fast applies.
User: "fix the OOM in train.py" → NOT eligible (bug_debug applies; unknown scope).
