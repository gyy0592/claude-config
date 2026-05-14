# reflect protocol (REFLECT status detail)

A REFLECT cycle is a bounded dialectic between `main` and one rebuttal subagent.
main drives via SendMessage; the subagent writes markdown and sleeps.

## File layout

`.barry_workflow/reflection_<round_id>.md` — shared markdown view. main creates
it from `content/templates/reflection_template.md` interpolating session id,
reason, and round id (e.g. `r1-on-anomaly-2026-05-13T05:08Z`).

## Sequence

1. main fills `## main's questions` with 3–7 specific questions (concrete file
   paths / log lines / observables).
2. main spawns the rebuttal agent via `Agent(run_in_background=true)` with the
   prompt below (see `reflect_subagent_prompt.md`). The prompt names the
   `reflection_<round_id>.md` path.
3. Agent reads the file, fills `## reviewer reply` (round 1), then sleeps in
   a loop waiting for SendMessage.
4. main reads the file; if more rounds needed, sends a SendMessage to the
   agent ("round 2: I disagree with X because…").
5. Agent wakes, appends `### round N` to `## reviewer reply`, sleeps again.
6. Loop until either (a) main sends a SendMessage containing
   `[CONSENSUS_REACHED]` + agreed action list, or (b) N rounds elapsed.
7. main writes the consensus block, calls `transition.sh REFLECT_DONE`, and
   shuts down the agent (TaskStop or KillBash).

## N (round budget)

- Default `N=5`. Pilot value from v4 plan §1 Q5.
- If a REFLECT cycle hits `N=5` without consensus, log it under
  `rule_violations.md` ("REFLECT N=5 exhausted on <reason>") and re-spawn
  with `N=10` fallback.
- If N=10 also fails: stop, write `[REFLECT_FAILURE]` in action_<sid>.md,
  surface to user.

## REFLECT reason

Single REFLECT prompt parameterised by reason ∈ {pre-task, on-anomaly,
post-task}. Each reason emphasises a different verification axis:

| reason | what the agent checks |
|--------|----------------------|
| pre-task    | plan completeness, missing observables, ambiguous success criteria |
| on-anomaly  | hypothesis vs evidence, alternative root causes, fix vs symptom |
| post-task   | deliverable matches success criterion, ledgers updated, no abandoned work |

main names the reason in the spawn prompt; agent adapts wording but keeps
the rebuttal contract.
