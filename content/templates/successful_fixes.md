<!-- template version = v2.0 (claude-config-v2-hook) -->
# Successful Fixes — Archive of What Actually Worked

**Scope**: Project-level (per `militar_camp/`).
**Purpose**: Permanent record of the **final winning fix** for each significant bug / improvement, AFTER multiple attempts. Distinguishes one-shot lucky fixes (rare) from hard-won fixes (common).
**Why this matters**: When a similar bug recurs, the AI can find the proven solution instead of re-exploring hypothesis space.

## When to write a FIX-N entry

Write a FIX-N entry when ALL of:
- The bug or target is genuinely resolved (retest passes 3-Q check: ran cmd + waited for results + matched success criterion)
- The fix has been stable for ≥ 1 verification round (not just "just worked once")
- The path to the fix involved >1 attempt OR is non-obvious enough to be worth recording

For trivial one-line typo fixes that worked first try, just leave them in `operation_log.md` + `attempts_ledger.md`. Don't pollute this file.

## Schema

```
## FIX-N — <punchy one-line description of the fix>

- **Time fixed**: YYYY-MM-DD HH:MM UTC
- **Target / bug**: <what was broken>
- **Final approach**: <the approach that worked, in 2-4 sentences>
- **How many attempts led here**: <N> (see ATT-X, ATT-Y, ATT-Z)
- **Linked ATT entries**: ATT-N (winning) + linked WRONG-WAY-M (failures along the way)
- **Commit IDs**: abc123 (the fix commit) + def456 (any follow-up verification commits)
- **Before [OBSERVE]**: <verbatim from earliest failure>
- **After [OBSERVE]**: <verbatim from final retest, must show pass>
- **Why this worked (root cause + mechanism)**:
  <Real explanation, NOT "removed bug". Cite line numbers, mechanism, why other approaches failed>
- **Cost paid total**: <wall clock + tokens + compute, summed across all attempts>
- **Stability verification**: <how many subsequent runs / time elapsed without regression>
- **Generalizable lesson**: <one paragraph — what's the takeaway for similar bugs in this or other projects?>
- **Tags**: `<tag1>` `<tag2>` (for future grep — e.g. `cuda-oom`, `memory-leak`, `dataloader`)
```

## Example

## FIX-1 — Memory leak in custom DataLoader (root cause: unbounded list append)

- **Time fixed**: 2026-05-12 17:42 UTC
- **Target / bug**: CUDA OOM at varying steps during training, correlated linearly with step count
- **Final approach**: In `custom_loader.py:78`, the `self.processed_cache` list was being appended every batch without bounds. Replaced with `collections.deque(maxlen=256)` to give it a hard cap. Memory now stable at ~14 GB across full epoch.
- **How many attempts led here**: 4 (ATT-1, ATT-2, ATT-3 failed; ATT-4 succeeded)
- **Linked ATT entries**: ATT-4 (winning), WRONG-WAY-1 (the batch_size dead-end)
- **Commit IDs**: e0f1a2 (fix), e0f1a3 (added unit test for cache bound)
- **Before [OBSERVE]**:
  ```
  [OBSERVE OBS-3] cmd: tail logs/train.log | grep OOM | value: "OOM at step 1240"
  [OBSERVE OBS-7] cmd: tail logs/train.log | grep OOM | value: "OOM at step 1640" (after batch_size cut)
  ```
- **After [OBSERVE]**:
  ```
  [OBSERVE OBS-15] cmd: tail logs/train.log | grep -E "OOM|step" | tail -3 | value:
                       "step=24000 loss=2.31 gpu_mem=13.8GB"
                       (no OOM, full epoch completed)
  [OBSERVE OBS-16] (re-run 12 hours later): same — stable
  ```
- **Why this worked (root cause + mechanism)**:
  The cache list grew ~50 MB / step because each batch appended preprocessed tensors that were never freed. By step 1240, accumulated cache exceeded GPU memory. Lowering batch_size only delayed the OOM because the cache growth was per-step, not per-tensor-size. The `deque(maxlen=256)` keeps only the last 256 entries, bounding memory regardless of step count.
- **Cost paid total**: ~4 hours wall clock + ~5 SLURM jobs + ~14K tokens (3 wrong attempts + 1 right)
- **Stability verification**: Trained 3 full epochs (24K steps each) without OOM; cache memory stable at ~16 MB.
- **Generalizable lesson**: When OOM correlates linearly with step count rather than batch_size, check for unbounded data structures BEFORE tweaking batch / precision / accumulation. Memory_profiler is the right tool. Common offenders: list / dict caches that never evict.
- **Tags**: `cuda-oom` `memory-leak` `dataloader` `unbounded-cache`

## Don't celebrate prematurely

A "fix" that only worked once is not yet a FIX-N — keep it in `attempts_ledger.md` with verdict `worked` and wait for stability verification. If it regresses, downgrade to WRONG-WAY-N in `bitter_lessons.md`.
