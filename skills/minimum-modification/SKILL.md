---
name: minimum-modification
description: Strict process for the smallest possible diff when the user asks to modify code or docs. Trigger aggressively whenever a user says "最小修改" / "别动其他东西" / "改得太多" / "画蛇添足" / "我没让你做那个" / "顺手改" / "minimum modification" / "only fix X" / "don't touch anything else" / "no scope creep", AND whenever the AI is about to touch more than about 5 lines or files outside the literal target. The skill enforces a scope rule, a mandatory plan-before-action gate, a visible 3-round self-review loop that is EXPOSED to the user, and a per-line justification pass. Undertriggering produces drive-by edits, formatter runs, unsolicited refactors, and 画蛇添足.
---

# minimum-modification

## 1. Scope rule (violation is severe)

The user said "fix X". The output fixes X and nothing else. Adjacent does not mean relevant. Proximity in the file is not license to edit.

Specifically forbidden unless the user explicitly asked:
- refactor adjacent code
- add defensive checks for cases not raised
- clean up "while I'm here"
- rename variables for readability
- remove unused imports
- run a formatter or linter
- add tests
- add docstrings
- re-order functions
- fix unrelated bugs noticed in passing

Any addition outside the user's explicit ask is 画蛇添足 and is forbidden. If a truly unrelated bug is noticed during the work, the correct action is to mention it to the user as a separate finding, not to fix it silently.

## 2. Task decomposition

Before touching anything, ask in writing: can this task be split into independent, decoupled subtasks? If yes, write down the subtask list, pick the one that matches the user's ask, and treat every other subtask as out of scope — even code belonging to those other subtasks that happens to live nearby.

## 3. Plan before action (hard gate)

No code edits are allowed before the plan exists. The plan is a written markdown block containing:
- list of files that will be modified
- for each file, approximate line numbers
- for each edit, a one-line justification tying it directly to the user's explicit ask

If a file or line cannot be justified in one sentence that quotes or paraphrases the user's ask, it does not belong in the plan.

## 4. Three-round self-review (visibly written out)

After writing the initial plan and before making any edit, run three rounds of self-review. All three rounds must be written out to the user, even if the answer each round is "no further reduction". The visibility is the point: it exposes the thinking and forces actual reduction rather than pro-forma compliance.

Round 1: "The current plan changes N1 lines. Can I achieve the same effect by changing fewer? Which lines could be removed or merged? Is there a tighter edit (e.g. a one-line change instead of a refactor, a conditional instead of a new branch)?" Produce the revised plan.

Round 2: "The round-1 plan changes N2 lines. Can I tighten further? Is any line still there only because it was in the original plan, not because the user's ask requires it?" Produce the revised plan.

Round 3: "The round-2 plan changes N3 lines. Any final reduction possible? Is every remaining line minimally required?" Produce the final plan.

Only after all three rounds are written out may the AI touch code. Each round must show the delta from the previous round; silent no-op rounds do not count.

## 5. Execution

Implement the final plan exactly. No drive-by additions during implementation. If during implementation a line outside the plan seems tempting to change, the correct action is to stop, note the temptation to the user, and wait — not to fold the change in.

## 6. Verification (diff review, per-line justification)

After implementation, produce a diff and walk it line by line. For each changed line, answer: is this line strictly required by the user's ask? If any line fails justification, revert that line before handing back. This pass is not optional; it is the final gate.

## 7. Reporting to the user

The final output to the user includes: the plan, the three self-review rounds, the final diff, and a one-line justification per changed line. The user can then audit whether any 画蛇添足 slipped through. Transparency is the enforcement mechanism; the skill does not rely on the AI silently behaving.
