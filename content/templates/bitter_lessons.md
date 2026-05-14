<!-- template version = v2.0 (claude-config-v2-hook) -->
# Bitter Lessons — Archive of Failed Efforts

**Scope**: Project-level (shared across all tasks; lives at `$PWD/workspace/bitter_lessons.md`). Each entry MUST carry `task: <name>` + `tags:` so future sessions can filter by current task.
**Purpose**: Verbose archive of efforts that **failed** or proved to be **wrong direction**.
**Why this matters**: Stops AI from re-trying the same dead-end weeks later. The lesson is bitter because cost was paid (time, tokens, compute, frustration) — the value is preventing payment again.

## When to write a WRONG-WAY-N entry

A failed attempt becomes a `bitter_lessons.md` archive entry when ANY of:
- Same target failed 3 consecutive times with this approach (stop rule triggered)
- Significant cost was paid (>30 min compute / >5K tokens of work)
- The wrong direction was non-obvious — Commander or future AI is likely to try the same thing again

## Schema (more detail than attempts_ledger entries)

```
## WRONG-WAY-N — <punchy one-line description of the wrong direction>

- **Time started**: YYYY-MM-DD HH:MM UTC
- **Time abandoned**: YYYY-MM-DD HH:MM UTC
- **Target / bug**: <what we were trying to fix>
- **The wrong hypothesis**: <what we incorrectly believed would work, AND why we believed it>
- **What we tried (concrete actions)**:
  1. <step 1 + linked OP-X>
  2. <step 2 + linked OP-Y>
  3. <...>
- **Linked ATT entries**: ATT-3, ATT-4, ATT-5
- **Commit IDs touched**: abc123, def456, ghi789
- **Before [OBSERVE]**: <verbatim>
- **After [OBSERVE]**: <verbatim — should show NO improvement or REGRESSION>
- **Why this failed (root cause)**:
  <2-5 sentence explanation citing evidence, NOT speculation>
- **Cost paid**: <wall clock + tokens + compute>
- **Abandon criterion that triggered exit**: <specific signal — e.g. "after 3rd try same OOM appeared at step ~1100, gradient_accumulation theory falsified">
- **WARNING TO FUTURE AI**: <one-paragraph in second person — "If you see [symptom X], do NOT try [approach Y]. The actual problem is in [direction Z], see ATT-N+M.">
```

## Example

## WRONG-WAY-1 — "Reduce batch_size" doesn't fix this OOM (actual issue: memory leak in custom DataLoader)

- **Time started**: 2026-05-12 14:23 UTC
- **Time abandoned**: 2026-05-12 16:15 UTC
- **Target / bug**: CUDA OOM at step 1240 during eval
- **The wrong hypothesis**: We thought per-step memory was the issue and batch_size reduction would help. We believed this because nvidia-smi showed memory rising right before crash. This was a correlation, not cause.
- **What we tried (concrete actions)**:
  1. Reduced batch_size 64→32 (OP-1)
  2. Added gradient_accumulation_steps=2 (OP-2)
  3. Enabled bf16 (OP-3) — looked OK for 200 steps, OOM returned at step 1440
  4. Reduced batch_size further to 16 (OP-7) — OOM returned at step 1640
- **Linked ATT entries**: ATT-1, ATT-2, ATT-3
- **Commit IDs touched**: a1b2c3, d4e5f6, g7h8i9
- **Before [OBSERVE]**: `tail logs/train.log | grep OOM → "OOM at step 1240"`
- **After [OBSERVE]** (after 3 attempts): `tail logs/train.log | grep OOM → "OOM at step 1640"` — OOM just shifts step number, doesn't go away
- **Why this failed (root cause)**:
  Memory growth was linear with steps, not bounded by batch_size. Lowering batch_size just delays OOM. The actual problem is a list-of-tensors append in `custom_loader.py:line 78` that never frees, so memory grows ~50MB per step regardless of batch_size. Discovered via memory_profiler in ATT-4.
- **Cost paid**: ~2 hours wall clock + ~3 SLURM jobs + ~8K tokens
- **Abandon criterion that triggered exit**: 3-failure-rule (3 attempts same target — ATT-1, ATT-2, ATT-3 all hit OOM)
- **WARNING TO FUTURE AI**: If you see OOM at a specific step that linearly correlates with step count regardless of batch_size, do NOT try batch_size / accumulation / precision tweaks first. The problem is a memory leak in an unbounded data structure. Use memory_profiler before changing config. See ATT-4 for the actual fix.

## Live-update rule

If a WRONG-WAY entry is later proven not wrong (e.g. it was right but masked by another bug):
- Don't delete it
- Add a new section `## SUPERSEDED BY: <reason>` at top of that entry
- Update the abandoned ATT-N entries' verdicts accordingly

## Don't be afraid of bitter lessons

A repo with many WRONG-WAY entries is a HEALTHY repo. It means AI explored hypothesis space and reported faithfully. The alternative (no bitter_lessons file) means either (a) AI got lucky every time (suspicious) or (b) AI is hiding failures (Treason).
