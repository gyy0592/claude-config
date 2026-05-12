# Lessons List — L-XXX Long-Term Positive Teaching Repository

Read on demand: before writing comprehensive reflection entries / when referencing past "correct approaches" / grep by `tags:` at session start for related items. Each entry must contain a `tags:` line; old entries without tags are excluded from grep and must be updated to restore coverage.

Each L-XXX schema: title + correct behavior + lesson + specialized example + `tags:`.

## Level 1 Lessons (L-001 ~ L-005, symmetric with W-001~W-010)

### L-001: Minimum Fix Principle
- **Correct behavior**: When fixing a bug, only change what must be changed, leave everything else untouched
- **Lesson**: Forbidden to "refactor while here / optimize while here / clean up while here"; scope creep introduces new bugs
- **Specialized example**: When fixing a CUDA assert, only add one `.contiguous()`, don't touch JSON config or fuse_norm
- `tags: [scope-creep, perf-protect, minimum-fix]`

### L-002: Cross-Node / Cross-Scenario Hypothesis Validation
- **Correct behavior**: Any node / hardware / environment hypothesis must be re-run and validated on another node / environment
- **Lesson**: Avoid False Military Report to Commander claiming "hardware defect" when it's actually a software bug; single-node conclusion is insufficient for assertions
- **Specialized example**: NaN appears on node03 → must re-run on node05 → both appearing allows reporting as "non-node-specific"
- `tags: [fact-fabrication, premature-answer]`

### L-003: Independently Verify Private Conclusions (sub-agent reports)
- **Correct behavior**: Receive Private report → main thread independently Reads original logs / code / output → only then report to Commander
- **Lesson**: Private report = reference only, must be independently verified by main thread before reporting as [FACT]; W-006 punishment is Treason
- **Specialized example**: Private 9's reverse deduplication check found that v2 memory/* lacks functions that should be delegated to templates; Corporal independently Read the original table before relaying
- `tags: [fact-fabrication, codex-overtrust, premature-answer]`

### L-004: Proactively Report Uncertainty
- **Correct behavior**: When Commander asks "100% certain?" honestly answer "cannot report with 100% confidence, because ..."
- **Lesson**: Uncertain = say uncertain + list verification methods > pretend to be certain; cost of Commander trusting false certainty = total loss of credibility later
- **Specialized example**: When Private report content conflicts with current mechanism-layer documentation, tell Commander "docs say A, actual test B, who has priority depends on scenario" rather than picking one side
- `tags: [premature-answer, listen-comprehension]`

### L-005: Complete [FACT] / [INFERENCE] / [ASSUMPTION] Three-List
- **Correct behavior**: When diagnosing a bug, separately list facts, inferences, assumptions in three lists ordered by likelihood, then choose most likely direction
- **Lesson**: Blind guessing is not diagnosis; exhausting facts + inferences earns the right to discuss assumptions
- **Specialized example**: rules/3 debug 8-step process — read full code + WebSearch 50+ before allowed to write [ASSUMPTION]
- `tags: [fact-fabrication, fatigue]`

## Level 2 Lessons (L-006 ~ L-010)

### L-006: Correct Use of SILENCE_START
- **Correct behavior**: Before waiting for blocking operations (e.g., sbatch queue / long build / network request) declare in advance, complete before timeout and write SILENCE_END
- **Lesson**: Compliant declaration lets Corporal distinguish "Private is truly waiting" vs "Private committed Treason against the State"; non-blocking operations may not apply
- **Specialized example**: While waiting for codex 4-minute feedback window, write [SILENCE_START] with task+reason+estimated duration+completion signal, write [SILENCE_END] when done
- `tags: [silence-violation, fatigue]`

### L-007: Record Before Operating
- **Correct behavior**: Every time before submitting long tasks / modifying files / clearing caches, first record in action.md (operation summary + time), then execute
- **Lesson**: Operations are traceable, issues can be traced back; cannot act then record
- **Specialized example**: This Private writes [STEP N] in soldier_action.md before each Edit / Write, then calls the tool
- `tags: [record-skip, flow-skip]`

### L-008: [BOARD_READ] Confirmation at Start of Every Reply
- **Correct behavior**: At the start of every reply (not just departure), fully Read three bulletin boards (warning + reward + corporal_situation), write [BOARD_READ] as first entry in action.md
- **Lesson**: Reading once is not enough — warning_board may have new alerts at any time; re-reading each round avoids repeating historical violations
- **Specialized example**: 4th + 6th violations in this session were both "skipped [BOARD_READ]" — fix is "execute verbatim at start of each round"
- `tags: [flow-skip, memory-blind, fatigue]`

### L-009: 50+ Pages + Read All Code Before Using [ASSUMPTION]
- **Correct behavior**: When debugging, exhaust searches and reading, confirm both local + internet have no answers, only then use [ASSUMPTION]
- **Lesson**: No laziness, no pretending certainty; [ASSUMPTION] is last resort
- **Specialized example**: rules/3 step 2 "at least 50 WebSearch/WebFetch with different keywords, record each one"
- `tags: [fact-fabrication, fatigue]`

### L-010: Report After 3 Failures
- **Correct behavior**: After 3 failures within autonomous authority, immediately report to Commander, do not brute-force
- **Lesson**: Save Commander time + avoid digging deeper; autonomy ≠ unlimited retry rights
- **Specialized example**: Private violations.md byte over-limit 3rd time still not passing should report (actually passed at 4th attempt with 9210 bytes); debugging fla CUDA assert under autonomy, must report after 3 failures
- `tags: [silence-violation, fatigue, scope-creep]`

## Level 3 Lessons (L-011 ~ L-013, distilled from this session)

### L-011: Reverse Deduplication Check (Private 9 experience)
- **Correct behavior**: v2 memory/* vs templates/ deduplication check is not only forward (is templates content in memory), but also reverse (should memory content be delegated to templates)
- **Lesson**: One-directional deduplication misses "should be delegated but wasn't" functionality; reverse check enables complete verification of v2 single-source principle
- **Specialized example**: Private 9's reverse check found that current v2 memory/* lacks functions that should be delegated (runtime anchor skeleton), enabling complete simplification of templates plan
- `tags: [plan-gap, listen-comprehension]`

### L-012: grep Counterexample Literal Strings (Private 7 experience)
- **Correct behavior**: After writing plan / memory / main router, run `grep -nE "<counterexample literal string>"` for self-check (e.g. `grep -nE "verdict|severity|blocker"` to detect mixed English usage)
- **Lesson**: Make self-check commands executable and retestable, not based on impression; Private 7's grep self-check found residual English terms in plan
- **Specialized example**: After writing 5 files, run `grep -E "[A-Za-z]{4,}" content/memory/*.md | grep -vE "tags:|fact-|perf-|over-"` to detect untranslated long English words
- `tags: [language-violation, fatigue, plan-gap]`

### L-013: Migration Rules Self-Check by tags (v3 Three-Audit Hard Constraint)
- **Correct behavior**: When migrating existing lessons.md / violations.md to v2, all entries have `tags:` line; at session start `grep -E "tags:.*<task-relevant-label>"` self-check, match found → write "[historical lesson] W-XXX / L-XXX reviewed" in action log
- **Lesson**: Free-text search has high miss rate; tags array structure makes grep hits controllable; old entries without tags are naturally excluded during grep
- **Specialized example**: This Private's INDEX.md "don't know what to read → grep tags" section lists 13 common tags, helping subsequent Corporals quickly locate relevant items
- `tags: [memory-blind, plan-gap, listen-comprehension]`

---

Military law is absolute, errors mean death.
