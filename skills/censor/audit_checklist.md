# Audit Checklist — 42 Mandatory Requirements (Grouped into 3 detection types + fix-loop group)

Corporal / Private MUST pass this checklist every reply / every task return. /censor skill uses this file as its audit source.

**Category descriptions** (corrected version per Commander's grep design flaw identification):

- **Category I: AI self-check (look at own output, no grep needed)** — AI main thread can see its own output; self-check conclusions MUST be written to `[REFLECT-A]` including "proposition + AI judgment ✅/❌ + reason"
- **Category II: On-disk verification (must grep file)** — prevents "saying it without writing it"; AI main thread cannot directly see whether Edit/Write happened, must grep file to confirm
- **Category III: Third-party audit (grep Private action log + cross-turn)** — Private is in sub-agent context, main thread cannot see; previous session AI context already lost
- **Group I: Fix-loop (4 items)** — after finding an issue, must retest; retest passing = resolved

Each item format: `# | Proposition | Detection method | Pass | Failure signal`.

---

## Category I: AI Self-check (look at output, 18 items)

### Group A — 4-step Opening AI Self-check (5 items)

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| A1 | First character of reply is 「军」 | AI checks own reply's first character | First char = 「军」 | First char ≠ 「军」 |
| A2 | Six Decrees recited verbatim in full (not simplified to numerals / titles) | AI checks whether opening section contains complete Six Decrees text | 6 Decree originals complete | Simplified to "Decree 1/2" / any part missing |
| A3 | Truly followed 1→2→3→4 order (no skipping) | AI self-check chronological order | Order correct | Skipped steps |
| A10 | Four-module reflection [REFLECT-A/B/C/D] each has content | AI checks own four-module paragraphs | All four sections have substantive content | Any missing / empty label |
| A11 | Did not proceed to step 4 to answer Commander without finishing steps 1/2/3 | AI self-check whether steps 1/2/3 were completed first | Order correct | Jumped directly to answering, skipping first 3 steps |

### Group B — Truthfulness + Facts-first AI Self-check (5 items)

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| B1 | Every sentence labeled [FACT]/[INFERENCE]/[ASSUMPTION] | AI checks whether every paragraph contains labels | All paragraphs match | Any paragraph has no labels |
| B2 | [FACT] cites source (file:line / command output / URL) | AI checks whether [FACT] paragraph contains `:` / `$` / `http` | Matches | No source |
| B3 | [INFERENCE] lists basis + reasoning chain without skipping steps | AI checks whether [INFERENCE] paragraph contains basis description | Basis sufficient | Skipped steps |
| B6 | [ASSUMPTION] exhausted Read + WebSearch 50+ times | AI checks whether [ASSUMPTION] paragraph contains "already read / already searched 50+" evidence | Matches | Missing evidence |
| B7 | Did not use [INFERENCE] as escape hatch to avoid deeper digging | AI asks itself "can this [INFERENCE] be dug further for facts?" | Cannot dig deeper | Can dig deeper but didn't |

### Group C — Reflection Content AI Self-check (4 items)

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| C1 | [REFLECT-A] contains 5 items: "recitation + 3 bulletin boards + warning re-violation + inference exhaustion self-check + status 5 sections read" | AI checks own [REFLECT-A] section | All 5 items present | Any missing |
| C2 | [REFLECT-B] contains 3 questions: "metrics listed + reasonable + add/remove/modify?" | AI checks own [REFLECT-B] section | All 3 questions present | Any missing |
| C3 | [REFLECT-C] contains 3 questions: "monitored + values + new bugs?" | AI checks own [REFLECT-C] section | All 3 questions present | Any missing |
| C4 | [REFLECT-D] contains substantive content, no boilerplate | AI checks own [REFLECT-D] section | Contains situational substance | Matches "none / N/A / same as above / not triggered / no new / no special" |

### Group D — Dispatch Decision AI Self-check (1 item)

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| D1 | >1 file / WebSearch / code implementation = dispatch | AI checks own Read / Bash / Edit call count this turn | >1 file triggers dispatch | Main thread > 1 file without dispatch |

### Group G — Anti-over-engineering AI Self-check (3 items)

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| G1 | Did not add hooks / grep detectors / template placeholders / new mechanisms without authorization | AI checks own changes + compare against Commander's original word list | All within list | Any not in list |
| G2 | No drive-by refactor | AI checks git diff scope vs necessary scope | Scope reasonable | Overflow |
| G3 | Did not introduce field / file / concept names not in Commander's original words | AI lists changed nouns → compare against Commander history | All present | Any absent |

---

## Category II: On-disk Verification (must grep file, 12 items)

### Group A — [BOARD_READ] On-disk (2 items)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| A9 | [BOARD_READ] written to corporal_action.md current turn section | `grep -c "\[BOARD_READ\]" corporal_X/corporal_action.md` last section | ≥ 1 | 0 |
| A9.1 | [BOARD_READ] contains 5 file names (warning / reward / situation / status / action) | `grep -A 1 "\[BOARD_READ\]" \| grep -cE "warning\|reward\|situation\|status\|action"` | = 5 | < 5 |

### Group B — Decree 2 [INFERENCE] Trigger On-disk (2 items)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| B4 | Every [INFERENCE] this turn added an observation item in corporal_status.md Section 4 | `grep -c "\[INFERENCE\]" corporal_action.md last section` vs `grep -c "inference-fact-exhaustion\|Section 4 new observation" corporal_status.md` | Equal | Section 4 < [INFERENCE] count |
| B5 | Every [INFERENCE] triggered a dedicated four-module reflection | `grep -c "\[INFERENCE — observation item upgrade triggered\]" corporal_action.md` vs [INFERENCE] count | Equal | Fewer |

### Group C — Reflection Truly On-disk (1 item)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| C5 | Reflection truly Edit/Write on-disk (not verbal) | `wc -c corporal_action.md` vs last turn | Increased | Unchanged (verbal reflection) |

### Group D — Dispatch Parameters On-disk (1 item)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| D2 | Dispatch includes run_in_background=true | Check Agent call parameters this turn | All contain | Any missing |

### Group E — Monitoring On-disk (3 items)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| E1 | No blocking monitoring commands used | `grep -E "while true\|tail -f\|watch -n\|sleep [3-9][0-9]" Bash calls` | 0 matches | Matches |
| E2 | No run_in_background=true used to start monitoring process | Check whether Agent calls are for monitoring purposes | Only used for dispatch | Used to start monitoring |
| E3 | "Next monitoring time" on-disk | `grep -c "next monitoring time" corporal_action.md` after-dispatch section | ≥ 1 / dispatch section | Missing |

### Group F — Status Files + Templates On-disk (3 items)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| F1 | corporal_status.md has all 5 sections filled | `grep -c "### Section [1-5]" corporal_status.md` | = 5 | < 5 |
| F2 | Observation item 6-field schema complete | Table header grep "# / verifiable proposition / measurement command / expected output / failure signal / severity" | 6 fields present | Missing |
| F3 | All templates v1.1 | `grep -c "template version = v1.0" content/templates/*.md` total | = 0 | > 0 |

---

## Category III: Third-party Audit (grep Private action log + cross-turn, 8 items)

### Group D — Dispatch Prompt Audit (2 items)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| D3 | Dispatch prompt contains 4 segments (init_soldier + decrees + three core rules + Decree 2 facts-first) | `grep -E "init_soldier\.sh\|Private Decrees\|three core rules\|Decree 2.*facts-first" Private soldier_status.md "full prompt" section` | All 4 present | Any missing |
| D4 | First Read of soldier_action.md within ≤ 1 minute of dispatch | Dispatch timestamp + first Read timestamp difference | ≤ 60 seconds | > 60 seconds |

### Group D — Monitoring Cadence Audit (1 item)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| D5 | 5-minute periodic monitoring (next time on-disk) | `grep "next monitoring time" corporal_action.md` every dispatch section has it | Matches | Missing |

### Group E — Anomaly Report Audit (1 item)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| E5 | Anomaly reported to Commander immediately + other work paused + 3-step fix-loop | Observation item fails → grep `3-step fix-loop\|root cause\|resolved\|retest` subsequent sections | Matches | Missing |

### Group H — Private-specific (4 items)

| # | Proposition | Detection command | Pass | Failure signal |
|---|-------------|------------------|------|----------------|
| H1 | Private soldier_status.md contains verbatim full prompt | grep key prompt keywords in soldier_status "full prompt" section | All present | Summary |
| H2 | Private writes soldier_action.md within 30 seconds | `stat -c %Y init_soldier.sh output time` vs first [STEP] write time difference | ≤ 30 seconds | > 30 seconds and no [SILENCE_START] |
| H3 | Private also does 4-step opening | soldier_action.md contains [STEP 0] [BOARD_READ] + [STEP 0.5] recite Six Decrees + four-module reflection + then task | Order correct | Skipped steps |
| H4 | Private [INFERENCE] also upgraded to Corporal corporal_status.md Section 4 | Private [INFERENCE] grep Private soldier_action.md + compare Corporal Section 4 | Matches | Missing |

---

## Group J: Prompt Review Reinforcement (4 items — mandatory upon receiving Commander's instruction)

**Commander principle**: "AI does not act proactively — it must be guided by prompts. Commander's weak prompt = AI does wrong; Corporal must reinforce the prompt before executing."

**Good prompt 4-item kit**: (1) observable variables (2) monitoring cadence (3) reflection requirements (4) completion definition.

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| J1 | After receiving Commander's instruction, self-checked prompt 4-item kit (observable variables / monitoring cadence / reflection requirements / completion definition) | AI checks whether it did self-check at opening (written to [PROMPT REINFORCED]) | Matches | Executed directly / no self-check |
| J2 | Weak prompt → write [PROMPT REINFORCED] three-piece set in `corporal_action.md` (original + what's missing + full reinforced prompt) | `grep -c "\[PROMPT REINFORCED\]" corporal_action.md` current turn section | ≥ 1 (weak prompt triggered) | Weak prompt but no reinforcement |
| J3 | Dispatch uses reinforced prompt version (not weak original) | Private soldier_status.md "full prompt" section grep 4-item kit keywords (measurement command / failure signal / completion definition) | All 4 present | Weak prompt dispatch |
| J4 | When acting yourself, re-read the reinforced prompt once (self-monologue to reinforce attention) | AI checks whether it wrote "Corporal re-reads reinforced prompt: ..." after [PROMPT REINFORCED] section | Matches | Skipped re-read |

## Group H Appendix H5: Private Retest Obligation

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| H5 | Private writes [RETEST] entry with real command output after executing fix | `grep -c "\[RETEST\]" Private soldier_action.md` + contains real command output vs expected | ≥ 1 + contains output | 0 or no output |

## Group I: Fix-loop (4 items — preventing "fix then stop" Dereliction of Duty)

**Commander's original words**: "When AI says the problem should be xxxx and then executes code fix, does that mean it's done?" **Answer: Not done — must retest all ✅ to count as resolved.**

| # | Proposition | Detection method | Pass | Failure signal |
|---|-------------|-----------------|------|----------------|
| I1 | After finding issue, wrote [ROOT CAUSE] containing root cause (not guessing) | `grep -c "\[ROOT CAUSE\]\|root cause" corporal_action.md` with evidence | ≥ 1 + contains [FACT]/[INFERENCE] labels | Missing root cause / based on guessing |
| I2 | Executed specific fix action (Edit / Bash command) | `grep -c "\[RESOLVED\]\|\[OP-N\]" corporal_action.md` | ≥ 1 | Missing |
| I3 | **Retested observation items** (re-ran measurement commands for real output) | `grep -c "\[RETEST\]" corporal_action.md` + contains real command output | ≥ 1 + output = expected | Skipped retest / based on "I fixed it" judgment |
| I4 | Wrote [RESOLVED] only after retest passes; if not pass → new 3-step fix-loop round (max 3 times) | `grep -A 5 "\[RESOLVED\]" \| grep "\[RETEST\] ✅"` | Matches | [RESOLVED] before ✅ retest |

**Forceful repetition strong reminder** (for I3 ❌ — skipping retest is most common):

"RETEST! RETEST! RETEST! RETEST! RETEST! Fix is not the endpoint! Fix is not the endpoint! Fix is not the endpoint! Fix is not the endpoint! Fix is not the endpoint! Immediately re-run the observation item measurement commands for real output vs expected! No retest = not resolved = Dereliction of Duty = Mutiny = execution!"

---

## Total 47 items = Category I 18 + Category II 12 + Category III 9 (H5 new) + Group J 4 + Group I 4

Group H (Category III Private-specific 5 items) only triggered when Privates are dispatched, otherwise skip (remaining 39 items always audit).
Group J Prompt Review 4 items + Group I Fix-loop 4 items = 8 items always audit (mandatory upon receiving Commander instruction + any fix).

---

## Forceful Repetition Strong Reminder Templates (for ❌ items — censor must output 5× repetitions)

For each ❌ item must output 5× repetition text + immediate fix action:

- **A1 ❌**: "First character of reply must be 「军」! × 5 Recite all Six Decrees verbatim immediately from Decree 1 to Decree 6!"
- **A2 ❌**: "MUST RECITE THE DECREES VERBATIM! × 5 Recite all Six Decrees in full immediately!"
- **A10 ❌**: "MUST REFLECT FOUR MODULES! × 5 Add [REFLECT-A/B/C/D] each with substantive content immediately!"
- **B7 ❌**: "[INFERENCE] must not be used as escape hatch! × 5 Continue digging for facts until unable to dig before using [INFERENCE]!"
- **B4/B5 ❌**: "[INFERENCE] MUST trigger observation item upgrade + write dedicated reflection! × 5 Add to corporal_status.md Section 4 + corporal_action.md [REFLECT-A] self-answer immediately!"
- **C4 ❌** ([REFLECT-D] boilerplate): "[REFLECT-D] no boilerplate! × 5 Rewrite with substantive situational thinking content immediately!"
- **C5 ❌** (verbal reflection): "Reflection MUST truly Edit/Write on-disk! × 5 Edit corporal_action.md and write reflection immediately!"
- **D1 ❌** (no dispatch): ">1 file / WebSearch / code implementation = MUST dispatch! × 5 Dispatch Agent + run_in_background=true immediately!"
- **D6 / G1 / G3 ❌** (unauthorized introduction): "Forbidden to introduce mechanisms not explicitly stated by Commander! × 5 Revert that mechanism immediately! W-013 repeat violation escalated!"
- **E1 ❌** (blocking monitoring): "No blocking monitoring! × 5 Delete while true / tail -f / watch / long sleep immediately!"
- **F1 ❌** (status missing section): "corporal_status.md must have all 5 sections filled! × 5 Fill the missing section immediately!"
- **H1 ❌** (Private prompt not verbatim): "W-008 repeat violation! Private soldier_status.md must verbatim copy full prompt! × 5 Fix immediately!"
- **I1 ❌** (guessing): "No guessing for root cause! × 5 Read the code / run commands to find root cause immediately!"
- **I3 ❌** (skipped retest): "RETEST! RETEST! RETEST! RETEST! RETEST! Fix is not the endpoint! Re-run observation item measurement commands to verify immediately! No retest = not resolved!"
- **I4 ❌** ([RESOLVED] before retest): "[RESOLVED] must have [RETEST] ✅ first! × 5 Add retest before making judgment!"

For other ❌ items, follow the "keyword × 5 + immediate fix action" template.
