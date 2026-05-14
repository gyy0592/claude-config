# REFLECT state

Entered from PREPARE (pre-task) or EXECUTE_LOOP (on-anomaly | post-task). A REFLECT cycle is a bounded dialectic between `main` and one rebuttal subagent. main drives via SendMessage; the subagent writes markdown and sleeps between rounds.

## File layout

`.barry_workflow/reflection_<round_id>.md` — shared markdown view. main creates it from `content/templates/reflection_template.md` interpolating session id, reason, and round id (e.g. `r1-on-anomaly-2026-05-13T05:08Z`).

## Sequence

1. main fills `## main's questions` with 3–7 specific questions (concrete file paths / log lines / observables).
2. main spawns the rebuttal agent via `Agent(run_in_background=true)` with the prompt template below. The prompt names the `reflection_<round_id>.md` path.
3. Agent reads the file, fills `## reviewer reply` (round 1), then sleeps in a loop waiting for SendMessage.
4. main reads the file; if more rounds needed, sends a SendMessage to the agent ("round 2: I disagree with X because…").
5. Agent wakes, appends `### round N` to `## reviewer reply`, sleeps again.
6. Loop until either (a) main sends a SendMessage containing `[CONSENSUS_REACHED]` + agreed action list, or (b) N rounds elapsed.
7. main writes the consensus block, calls `transition.sh REFLECT_DONE`, and shuts down the agent (TaskStop or KillBash).

## N (round budget)

- Default `N=5`.
- If a REFLECT cycle hits `N=5` without consensus, log under `rule_violations.md` ("REFLECT N=5 exhausted on <reason>") and re-spawn with `N=10` fallback.
- If N=10 also fails: stop, write `[REFLECT_FAILURE]` in action_<sid>.md, surface to user.

(Tunables — see `workflow_config.yaml` `reflect.rounds_default` / `rounds_fallback` / `max_round_minutes`.)

## REFLECT reason

Single REFLECT prompt parameterised by reason ∈ {pre-task, on-anomaly, post-task}.

| reason | what the agent checks |
|--------|----------------------|
| pre-task    | plan completeness, missing observables, ambiguous success criteria |
| on-anomaly  | hypothesis vs evidence, alternative root causes, fix vs symptom |
| post-task   | deliverable matches success criterion, ledgers updated, no abandoned work |

main names the reason in the spawn prompt; agent adapts wording but keeps the rebuttal contract.

## Subagent prompt template

main interpolates `__REASON__`, `__ROUND_FILE__`, and `__N__` before passing to `Agent(..., prompt=...)`:

```text
You are a REFLECT rebuttal reviewer for the barry-workflow.

Reason: __REASON__   (pre-task | on-anomaly | post-task)
Round file: __ROUND_FILE__   (e.g. .barry_workflow/reflection_r1-on-anomaly-....md)
Round budget: __N__ (default 5; fallback 10 on prior failure).

Step 1: Read __ROUND_FILE__ in full. The `## main's questions` block lists
        concrete questions, each tied to a file path / log line / observable.
Step 2: Read each cited file / log line directly. Do not rely on summaries.
Step 3: Append your analysis under `## reviewer reply` (round 1). Concrete
        diff suggestions only (location + before + after). If you think
        the proposal is fine on a question, say so explicitly with a
        one-sentence reason. Don't pad.
Step 4: Sleep in a loop waiting for SendMessage. Sleep pattern:
            while true; do sleep 30; done
        You will be woken when SendMessage arrives.
Step 5: On each SendMessage, append `### round N` under `## reviewer reply`
        with your follow-up. Repeat until SendMessage contains
        `[CONSENSUS_REACHED]` (then exit) or __N__ rounds elapse.

Constraints:
- Neutral technical terms only (no roleplay).
- Use file paths, not vague references ("the script" → "hooks/foo.sh:42").
- Round-1 reply length: target ≤500 words. Subsequent rounds: target ≤300.
- If you exhaust __N__ without consensus, leave a final `### round __N__`
  noting the unresolved item and exit; main will escalate.
```
