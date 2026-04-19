---
name: general-rule-vs-patch
description: Re-calibrates the distinction between a good general rule and a bad patch when extending any rule system (CLAUDE.md, skill rulebook, coding-style guide, review checklist). Load whenever the user flags patching behavior ("不通用" / "修修补补" / "打补丁" / "抽象层不对" / "sibling rule smell" / "this is a special case of an existing rule"), AND whenever the AI is about to add a new rule to an existing rule list. This skill is a DEFINITION document, not a checklist. It teaches what "general" means so the AI can self-correct; it does not execute a workflow.
---

# general-rule-vs-patch

## 1. Definitions

A good general rule sits at a higher abstraction than the violations it governs. Stated once, it covers downstream cases automatically, without the author having to enumerate them. Over time, the rule system converges: new violations surface, but they turn out to be instances of rules that already exist, so the rulebook stops growing even as coverage grows.

A bad patch sits at the same abstraction as the violation. Each new violation class spawns a new sibling rule next to the existing ones. Over time, the rule system diverges: the rulebook grows linearly with observed violations, existing rules start overlapping, enforcement becomes brittle, and the whole list eventually collapses under its own weight.

The heuristic: if adding a rule feels like listing one more special case, it is probably a patch. If adding a rule feels like naming a principle that retroactively explains several unrelated prior rules, it is probably general.

## 2. Worked examples

Example 1 — homework skill, inequality witness

Symptom: user claims `u[n] != u[n-n_0]` for `n_0 != 0` without providing a witness.
Patch response (wrong): add STEP 11 "inequality witness check" as a sibling of STEPs 1 through 10 in the rule 3 search list.
General response (right): strengthen rule 3 ("zero jumps, micro-derivation"). Rule 3 already covers this case: asserting any relation, including `!=`, requires evaluating both sides, which is itself a derivation step. The patch lived in enforcement, not in the rule. The fix is to extend rule 3 with an explicit inequality example and add `\ne`/`\neq`/`not equal` to the literal search list of rule 3.
Why: the principle "zero jumps" already covers inequality claims. A sibling rule would imply inequalities are a distinct category, which they are not.

Example 2 — coding style, naming consistency

Symptom: contributor uses `userId` in one file and `user_id` in another.
Patch response (wrong): add a new rule "use snake_case for user identifiers".
General response (right): the style guide likely already says "follow the language's idiomatic casing" or "consistency within a module". Strengthen that rule with the observed example rather than create a user-id-specific rule.
Why: a user-id-specific rule invites parallel rules for order-id, product-id, and so on.

Example 3 — review checklist, test coverage

Symptom: a PR ships a new helper function without a unit test.
Patch response (wrong): add "every helper function must have a unit test".
General response (right): the checklist probably already says "public API changes require tests". If the helper is internal, the right action is often no rule change at all. If it is public, strengthen the existing API-test rule with an example.
Why: a helper-specific rule would compete with, rather than strengthen, the general API-test principle.

## 3. Hierarchy of preferred responses

When a new violation appears, walk these steps in order and stop at the first that applies.

Step A — Is this an instance of an existing rule, possibly at a higher level of abstraction? If yes, do not add a new rule. Strengthen enforcement of the existing rule: add the observed case as an example, extend its literal-search pattern, or clarify its scope statement.

Step B — Is this a violation type shared by two or more existing rules? If yes, refactor upward: consolidate those rules under a new higher-level rule that covers all of them plus the new case. The total rule count should decrease or stay flat, not grow.

Step C — Is this truly a new class, not covered even abstractly by any existing rule? This is rare. Only then add a new rule, and prefer to add it at a different abstraction level from existing rules rather than as a sibling.

## 4. Last-resort patching

If after sincere effort Steps A and B both fail, and Step C genuinely applies, the new rule must be placed at a different abstraction level than the existing rules it sits near. Sibling rules at the same abstraction level are the exact failure mode this skill exists to prevent. A new rule at a new abstraction level is an extension; a new rule at an existing abstraction level is a patch.

## 5. Self-check question

Before every rule addition, answer one question in writing: am I patching a symptom, or am I raising the abstraction? If the answer is "patching a symptom", do not add the rule. Return to Step A.
