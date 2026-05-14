<!-- template version = v2.0 (claude-config-v2-hook) -->
# Attempts Ledger — Per-Attempt Debug / Improvement Log

**Scope**: Project-level (shared across all tasks; lives at `$PWD/workspace/attempts_ledger.md`). Each entry MUST carry `task: <name>` + `tags:`.
**Granularity**: One entry per "I tried this to fix/improve X".
**Relationship to other files**:
- An ATT-N entry usually links to several `operation_log.md` OP-N entries (the concrete ops that constitute the attempt)
- If verdict = `failed` or `wrong-direction` → also archive to `bitter_lessons.md` as WRONG-WAY-N
- If verdict = `worked` after many tries → also celebrate as FIX-N in `successful_fixes.md`

## Schema

```
### ATT-N — <target / bug / improvement headline>

- **Time started**: YYYY-MM-DD HH:MM UTC
- **Time concluded**: YYYY-MM-DD HH:MM UTC (or "still in progress")
- **Actor**: Corporal N / Private N/M
- **Target**: <specific bug / metric / regression>
- **Hypothesis**: <why I thought this would work>
- **What I tried**: <approach in 1-3 sentences>
- **Linked OP entries**: OP-3, OP-4, OP-5
- **Commit IDs**: abc123 (apply), def456 (revert if reverted)
- **Before [OBSERVE]**:
  ```
  [OBSERVE OBS-N] cmd: <measurement> | value: <X> | conclusion: fail | severity: blocker
  ```
- **After [OBSERVE]** (re-ran SAME measurement command):
  ```
  [OBSERVE OBS-N+1] cmd: <same as above> | value: <Y> | conclusion: <pass/fail/partial>
  ```
- **Verdict**: worked / failed / partial / wrong-direction / still-investigating
- **Why this verdict**: <brief explanation citing the before/after values>
- **Next step**: <what to try next, or "stop, escalate" if 3-failure rule triggered>
- **Cross-references**: WRONG-WAY-N (if failed → archived) / FIX-N (if won → celebrated)
```

## Example

### ATT-1 — Fix CUDA OOM during eval

- **Time started**: 2026-05-12 14:23 UTC
- **Time concluded**: 2026-05-12 14:55 UTC
- **Actor**: Corporal 1
- **Target**: Eval crashes with `CUDA out of memory` at step 1240
- **Hypothesis**: batch_size too high; gradient accumulation should let us reduce per-step memory
- **What I tried**: Reduced batch_size from 64 to 32, added gradient_accumulation_steps=2
- **Linked OP entries**: OP-1, OP-2
- **Commit IDs**: a1b2c3 (apply)
- **Before [OBSERVE]**:
  ```
  [OBSERVE OBS-3] cmd: `tail -n 20 logs/train.log | grep OOM` | value: "OOM at step 1240" | conclusion: fail
  ```
- **After [OBSERVE]**:
  ```
  [OBSERVE OBS-4] cmd: `tail -n 20 logs/train.log | grep OOM` | value: no OOM, training continuing | conclusion: pass
  ```
- **Verdict**: worked
- **Why**: OOM eliminated, effective batch size preserved by accumulation
- **Next step**: Monitor 1 more epoch to confirm no regression
- **Cross-references**: FIX-1 (will create after 1 epoch holds)

## Live-update rule

When later attempts reveal an earlier verdict was wrong (e.g. "worked" was actually masking a different bug):
- Don't delete the original ATT-N — keep it as historical record
- Add a **new ATT-N+M** entry that supersedes it, with `Cross-references: ATT-N (superseded — reason)`
- Update the original ATT-N's verdict to `superseded by ATT-N+M` (one-line edit allowed)

## Don't lose this history

If an attempt fails badly, the temptation is to delete it from the record. Don't.
A logged failure prevents repeating the same wrong direction next time the same bug recurs.
