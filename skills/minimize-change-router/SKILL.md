---
name: minimize-change-router
description: Dispatcher that routes to one of two sub-skills whenever a change-related concern surfaces. Load this skill whenever the user pushes back on a rule/code change with phrases like "这不通用" / "不是 general" / "修修补补" / "又在打补丁" / "抽象层不对" / "patching" / "补丁" / "画蛇添足" / "改得太多" / "别动其他东西" / "最小修改" / "我没让你做那个" / "顺手改" / "minimum modification" / "scope creep", AND self-trigger internally whenever the AI is about to (a) add a sibling rule to an existing rule system or (b) touch more than ~5 lines of code or docs. This router does no work itself; it only selects the correct sub-skill. Trigger aggressively — undertriggering leaves the AI to patch-and-sprawl without guardrails.
---

# minimize-change-router

## Purpose

Dispatcher. Holds no content of its own. Picks exactly one of two sub-skills and hands off.

## Dispatch table

Trigger class A (abstraction-level complaint about rules/docs):
- User phrases: "不通用" / "不是 general" / "修修补补" / "又在打补丁" / "抽象层不对" / "patching" / "补丁" / "这条规则是 X 的特例" / "sibling rule smell"
- Self-trigger: AI about to add a new rule to an existing rule list
- Action: stop. Read `/home/yguo173/.claude/skills/general-rule-vs-patch/SKILL.md`. Follow its definitions before proposing any rule change.

Trigger class B (scope/diff-size complaint about code/doc edits):
- User phrases: "最小修改" / "别动其他东西" / "改得太多" / "画蛇添足" / "我没让你做那个" / "顺手改" / "minimum modification" / "scope creep" / "only fix X"
- Self-trigger: AI about to modify more than about 5 lines, or touch files outside the literal target of the user's ask
- Action: stop. Read `/home/yguo173/.claude/skills/minimum-modification/SKILL.md`. Follow its 3-round self-review loop before any edit.

## Ambiguity rule

If both trigger classes apply (e.g. user complains about both abstraction and scope in one turn), load sub-skill 1 first, then sub-skill 2. Rule-level concerns subsume code-level concerns because a wrong rule produces many wrong diffs.

## What this skill does NOT do

Does not argue, does not defend the prior output, does not produce a fix. The only output of this router is a decision: which sub-skill to load next.
