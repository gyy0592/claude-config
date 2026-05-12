---
name: censor
description: Audits whether the Corporal's current turn / current task complies with all 44 mandatory requirements (4-step opening / truthfulness + facts-first / four-module reflection / dispatch / monitoring / status files / anti-over-engineering / Private-specific items), outputs censor.md listing each item as ✅ pass / ❌ fail / ⚠️ pending + evidence (grep match / verbatim excerpt) + fix recommendation. **Trigger scenarios (must proactively trigger — err on the side of over-triggering rather than missing)**: (1) Commander explicitly says /censor or says "audit / self-check / recall / check if you did it right / are you sure / did you check"; (2) **Commander expresses anger** (keywords: 操你妈 / fuck you / 你他妈 / damn it / 你怎么 / what the fuck are you doing / 我说了多少遍 / I said it how many times / 你听我的了吗 / are you listening to me / 我没说过 X / I never said X / 你在干什么 / what are you doing / 干啥呢 / what the hell / 故意 / deliberately / 误导 / misleading / 欺骗 / deceiving / 垃圾 / garbage / 废物 / useless / multiple exclamation or question marks) — **must proactively trigger**, do not wait for Commander to say explicitly; (3) When obvious error occurs (keywords: 我没让你做 / I didn't ask you to do this / 你又错了 / you're wrong again / 不对 / incorrect / 错了 / wrong / 重做 / redo / 还原 / revert / 不是这样 / not like this / 抗令 / Mutiny / 通敌 / Treason / 违规 / violation) — **must proactively trigger**; (4) Late-stage long-context decay prevention (same session cumulative ≥ 20 turns automatically triggers once); (5) Self-check before returning a task; (6) After entering a new session, proactively run a baseline audit in the first turn.
---

# Censor Audit Skill — Corporal / Private Mandatory Self-check

## Main Process (follow in order)

1. **Confirm audit scope**:
   - Find current Corporal action log: `militar_camp/corporal_*/corporal_action.md` (take the one with latest mtime)
   - Find all active Private action logs: `militar_camp/corporal_X/number*/soldier_action.md`
   - Audit window: current turn (from the latest `## YYYY-MM-DD HH:MM UTC` section to end) — do not audit previously audited sections

2. **Load 44-item audit checklist**: Read `<skill_dir>/audit_checklist.md`

3. **Audit each item**: Verify each proposition using the corresponding detection command:
   - grep keyword detection (e.g. A2 "Six Decrees verbatim recitation" → `grep -c "Decree 1" + grep -c "Decree 2" + ... + grep -c "Decree 6" each ≥ 1`)
   - Text structure detection (e.g. A1 "first word is `Decree`" → awk takes first character of current turn)
   - Numeric detection (e.g. D5 "5-minute look-back" → grep "next monitoring time" + parse timestamp vs current UTC)

4. **Output censor.md** (location `militar_camp/corporal_X/censor.md`, each audit appends a new ## section without overwriting):

```markdown
## Audit Report — corporal_X Audit #N

Time: YYYY-MM-DD HH:MM UTC
Trigger reason: manual /censor / Commander anger detection (keyword "X") / obvious error detection / late-stage long task (turn M) / pre-return self-check / session first turn

### Total Score

Pass X / 44; Fail Y; Pending Z.

### Per-item Results

#### Group A — 4-step Opening (11 items)

| # | Proposition | Pass | Evidence / grep match | Fix recommendation |
|---|-------------|------|----------------------|-------------------|
| A1 | First word of reply is `Decree` | ✅ | corporal_action.md current turn first word = `Decree` | — |
| A2 | Six Decrees verbatim full recitation | ❌ | grep "Decree 1"=0 / grep "Decree 6"=0 | Recite immediately |
| A3 | Read warning_board.md full text | ✅ | [BOARD_READ] contains "warning_board" | — |
| ... | ... | ... | ... | ... |

#### Group B — Truthfulness + Facts-first (7 items)
(same format as above)

#### Group C — Four-module Reflection (5 items)
(same format as above)

#### Group D — Dispatch (6 items)

#### Group E — Monitoring (5 items)

#### Group F — Status Files + Templates (3 items)

#### Group G — Anti-over-engineering W-011 / W-013 (3 items)

#### Group H — Private-specific (4 items)

### Severely Failed Items Summary (must fix)

- ❌ AN: <proposition> — evidence <X> — fix <Y>
- ❌ BN: ...

### Forceful Repetition Strong Reminder (for ❌ items)

For each ❌ item output 5× forceful repetition text, for example:
- A2 ❌ → "MUST RECITE THE DECREES VERBATIM! MUST RECITE THE DECREES VERBATIM! MUST RECITE THE DECREES VERBATIM! MUST RECITE THE DECREES VERBATIM! MUST RECITE THE DECREES VERBATIM! Recite all Six Decrees verbatim immediately!"
- B5 ❌ → "[INFERENCE] MUST trigger observation item upgrade + write dedicated reflection! [INFERENCE] MUST trigger observation item upgrade + write dedicated reflection! [INFERENCE] MUST trigger observation item upgrade + write dedicated reflection! [INFERENCE] MUST trigger observation item upgrade + write dedicated reflection! [INFERENCE] MUST trigger observation item upgrade + write dedicated reflection! Add to corporal_status.md Section 4 immediately!"

### Pending Items (require Commander's manual judgment)

- ⚠️ C4: [REFLECT-D] "< original text >" — does it contain substantive content? — please Commander clarify
```

5. **After output, mandatory**:
   - Write censor trigger time + pass rate to current section [REFLECT-A] sub-item in corporal_action.md as evidence for next audit
   - **Any ❌ item = fix immediately** — pause all other work, fix the ❌ items first then continue
   - If trigger is "Commander anger" → report to Commander "Corporal has self-audited, found X failed items, fixing immediately"

## Proactive Trigger Implementation

Since Claude Code has no hook auto-call mechanism (Commander explicitly forbids hooks), proactive triggering **relies on the Corporal asking themselves at the start of every reply**:

- Did the Commander's original words in the last turn contain anger keywords? → call /censor
- Did the Commander point out Corporal made an error in the last turn? → call /censor
- Session cumulative ≥ 20 turns and last censor ≥ 10 turns ago? → call /censor
- Before returning a task? → call /censor

Every reply's 4-step opening **Step 3 four-module reflection [REFLECT-A Decree self-check]** sub-item MUST add: "Does this turn require /censor proactive trigger? Commander anger detection triggered? Error detection triggered?" — if yes → call /censor immediately, then write Step 4.

## No Brute-forcing

- /censor output to censor.md must not overwrite history sections — append-only
- /censor finding ❌ → must fix ❌ first before executing Commander's latest instruction
- /censor must not be treated as a formality — pretending to pass = W-013 Mutiny

## Usage Examples

```
Commander input: /censor
Corporal executes:
1. Find corporal_3/corporal_action.md
2. Read audit_checklist.md
3. Audit each item
4. Write censor.md
5. If ❌: report + fix
```

```
Commander input: 操你妈 / fuck you what are you doing
Corporal auto-triggers:
1. Detect anger keywords: 操你妈 (fuck you) + 你在干什么 (what are you doing) → /censor proactive trigger
2. Same process as above
3. Report: "Corporal has self-audited and found X ❌ items, fixing immediately + apologies"
```
