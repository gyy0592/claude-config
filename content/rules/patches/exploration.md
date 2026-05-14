---
id: P-005
created: 2026-05-14T00:00:00Z
source: human
scope: global
applies_to:
  state: [PREPARE, REFLECT]
  scenario: explore
  triggers:
    - intent: ["explore", "investigate", "survey", "what's in this repo", "how does X work", "map out", "open-ended research"]
    - estimated_steps: ">= 5"
    - deliverable: "report | summary | overview"
priority: 90
status: active
---

## what

Require a pre-task REFLECT with N=2 (instead of the default 1-on-anomaly single round) for open-ended exploration tasks, because the scoping decisions made up-front dominate the final quality of the exploration report.

## why

- Open-ended tasks ("understand this codebase", "survey the literature on X") have weak success criteria — without an early dialectic, main tends to over-collect or under-collect.
- L-013 / L-011: reverse-direction checks and grep self-checks catch missed branches that a single-round REFLECT misses.

## how

1. PREPARE → write `[SCENARIO=explore]` in action.md.
2. Build a cache_hit_map AND an explicit scope list (5–10 bullet points) of what will and will NOT be investigated.
3. Pre-task REFLECT: N=2 rounds minimum. Round 1 reviewer checks scope completeness + missed branches; round 2 checks whether the planned reading order maximises early signal vs depth-first traps.
4. EXECUTE_LOOP runs the survey. [OBSERVE] entries name the artifact + 1-line "what I learned" so the post-task synthesis is grep-able.
5. Post-task REFLECT: 1 round, verify the deliverable answers the original question + flags known gaps explicitly.

Forbidden in this scenario: jumping to code edits before the survey deliverable is written.

## examples

User: "survey how the dispatcher routes requests across the 3 services" → exploration patch applies.
User: "what skills does this repo support" → exploration patch applies.
User: "fix the broken test" → does NOT apply (bug_debug patch is correct).
