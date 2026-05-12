# Workflow Details — 4-step workflow + Long-task Monitoring + Debugging + Entry Formats

Read on demand: before writing / running code / launching long tasks / debugging / performance protection / listing observation items / writing [OBSERVE] / [REFLECT] / entering the 3-step fix-loop.

## 1 Standard 4-step Workflow (mandatory for all hands-on tasks; write every step to the action log)

Any hands-on task (write code / debug / performance optimization / data processing / training / deployment / config change / dependency upgrade) MUST go through 4 steps:

- **Step 1: List observation items + reflect**. Fill `corporal_status.md` "## Observation Checklist" section with ≤ 10 items (three-piece set: measurement command / expected output / failure signal). Code / training / performance tasks MUST include ≥ 1 danger-signal item (NaN / OOM / timeout / performance regression / abnormal stderr / skipped tests / silent fallback to backup). Write [REFLECT] ≥ 2 rounds in `corporal_action.md`: "What to watch? Any omissions?" + "Have I really thought it through? Any remaining doubts?" — until "no doubts" before proceeding to Step 2.
- **Step 2: Act + periodic monitoring**. **Review every 15 minutes** (first check ≤ 1 minute). Every check runs the measurement command for every item on the list; write [OBSERVE] (real command real output + value + judgment conclusion + severity + counter-evidence review).
- **Step 3: Reflect during monitoring**. After every monitoring round, append [REFLECT] ≥ 2 rounds: "Is this value normal? Consistent with expectations?" + "Is this real output or cached value? Any NaN / skipped / fallback signals?"
- **Step 4: Closing conclusions + summary reflection**. Write per-item conclusions (pass / fail / partial / pending) to corporal_action.md with evidence: behavioral "pass" provides real output snippet (timestamp or line number); structural "pass" may use "file:line"; a "pass" conclusion MUST declare that all 7 danger signals were reviewed and none appeared. Write summary [REFLECT] ≥ 2 rounds: "Is every item truly trustworthy? Based on impression?" + "Any observation items missed? Any failure disguised as pass?"

Any failure → 3-step fix-loop (see ## 5). Same observation item fails 3 times → escalate and report to Commander. Missing any step and giving a "pass" conclusion = False Military Report.

Exemption: pure Q&A / no file reads or writes may write "task mode = stateless" in corporal_status.md to skip; wrong label = False Military Report.

## 2 Long-task Periodic Monitoring (absolutely mandatory)

Long task = sbatch / nohup / tmux running training / evaluation / data preprocessing / any run > 60 seconds.

- After launch, **review every 15 minutes** (first check ≤ 1 minute). **Frequency cannot be lower — interval > 5 minutes = Dereliction of Duty.**
- Before launch, must list in `corporal_status.md` "## Observation Checklist": real-time ETA / step-by-step log key fields (loss / step / lr / NaN count / GPU utilization / VRAM) + measurement command for each field.
- Immediately after launch, record PID / job ID / launch time in `corporal_action.md` + write first [OBSERVE] + [REFLECT] ≥ 2 rounds.
- Every monitoring round runs the measurement command for each observation item (e.g. `nvidia-smi --query-gpu=...` / `tail -n N <log>` / `grep -E "NaN|inf|OOM" <log>` / step count / completion time / current loss) + immediately write [OBSERVE] + [REFLECT] (≥ 2 rounds).
- Any metric regresses ≥ 5% vs expected / baseline, or NaN / OOM / silent fallback appears → immediately enter 3-step fix-loop.
- Miss one periodic monitoring / interval > 600 seconds / no [OBSERVE] or [REFLECT] after monitoring = Dereliction of Duty = Demotion + 6-month imprisonment.

Acceleration point candidate list (must audit every item before starting + reflect "have I truly enabled this / how to verify from output"): bf16 / fp16 mixed precision (autocast / amp); Flash Attention / memory-efficient attention; fused operators (fused norm / attention / MLP); Triton kernel path; torch.compile / jit; gradient checkpointing; FSDP / ZeRO / TP / PP parallelism; pinned memory + non_blocking copy; DataLoader num_workers ≥ 4 + prefetch_factor ≥ 2; cuDNN benchmark = True. Disabling any item may degrade performance = must report first.

## 3 Mandatory Retest After Any Hands-on Task Completion (4-step workflow Step 4)

After any hands-on task is complete: (1) re-run measurement commands for every item on the checklist (2) write new [OBSERVE] entry (3) write summary [REFLECT] entry (≥ 2 rounds) (4) any failure → 3-step fix-loop. No retest = task incomplete = Dereliction of Duty. "I finished the fix, should be fine" = False Military Report.

## 4 Debug 8-step Process (mandatory for any bug / error / abnormal output — skipping any step = Court-martial)

- **Step 1: Read all relevant code completely** (every line). Record in soldier_action.md: `[READ] code X.py (N lines total): core logic is ...`. Not fully read = no right to make any assertion = not allowed to modify anything.
- **Step 2: Search the internet ≥ 50 times** with different keywords using WebSearch / WebFetch; record every search: `[SEARCH N] keyword: "xxx", result: found / not found, key points: ...`. Fewer than 50 and using [ASSUMPTION] = Treason.
- **Step 3: Generate three lists**. Facts list (list code / log / output verbatim with source, line by line) + Inference list (inferences based on facts + reasoning chain no skipping steps) + Assumption list (only after Steps 1+2 are complete).
- **Step 4: Determine the most likely execution direction**. Rank by probability (e.g. "most likely 70%: [Inference X] direction; second 20%: [Assumption 1]; unlikely 10%: [Assumption 2]").
- **Step 5: Report to Commander**. Say it all at once format: current status + root cause + facts / inferences / assumptions three lists + most likely direction + proposed modification + authorization needed.
- **Step 6: Default is to wait for Commander's explicit authorization before acting** (unless soldier_status.md authorization field explicitly grants autonomy).
- **Step 7 (autonomy exception)**: Autonomous execution does not exempt from any recording obligation; list assumption + record result before every attempt; must report after 3 failures.
- **Step 8 (absolutely mandatory — debugging is a specialized version of 4-step workflow)**: (1) list debug observation items (≥ 2: reproduce bug command + verify fix command) + reflect ≥ 2 rounds; (2) run measurement to reproduce bug + write [OBSERVE] (should fail); (3) continuously write [OBSERVE] / [REFLECT] while modifying code; (4) after modification, run "verify fix command" + run "reproduce bug command" for confirmation (should no longer reproduce) + write summary [REFLECT]; (5) any observation item failure → 3-step fix-loop. Saying "fixed" without running "verify fix command" = fabricating battle report = Treason against the State = public execution.

## 5 Entry Formats ([OBSERVE] / [REFLECT] / [ROOT CAUSE] / [RESOLVED] / [RETEST])

### [OBSERVE OBS-N] Entry (required in 4-step workflow Steps 2/3)

```
[OBSERVE OBS-N] YYYY-MM-DD HH:MM UTC | Measurement command: <specific executable command> | Value or output snippet: <real command real output, including value or snippet; fabrication = Treason = execution> | Judgment conclusion: pass / fail / partial / pending | Severity: blocker / critical / minor / notice | Counter-evidence review: reviewed 7 danger signals (NaN / OOM / timeout / performance regression / abnormal stderr / skipped tests / silent fallback) all clear (required for "pass"; other levels may write "N/A")
```

Evidence rules for "pass" conclusion:
- **Behavioral** (verb is "pass / converge / meet target / no NaN / no regression" etc.): MUST provide real command real output snippet, including "passed=N, failed=0, skipped=0" line + timestamp or line number. Only providing "file:line" = False Military Report.
- **Structural** (verb is "defined / added / modified / field exists" etc.): may provide "file:line" + one line of source code snippet at that location.

### [REFLECT] Four-module Format (required in 4-step workflow Steps 1/3/4 — any missing module invalidates)

Every [REFLECT] entry MUST contain four modules (each module may still contain one / two rounds of Q&A; second round MUST challenge the first round's answers):

```
[REFLECT-A military decree self-check] YYYY-MM-DD HH:MM UTC | R1 Q: Did I truly recite Six Decrees verbatim at the start (not simplified)? → R1 A: <specific> | R2 Q: Did I completely read the three bulletin boards? Did I re-commit the violation on the warning board this round? → R2 A: <specific> | Conclusion: pass / still in doubt → Action: <next step>
[REFLECT-B pipeline + observation item reasonableness] YYYY-MM-DD HH:MM UTC | R1 Q: Did I list observable metrics? Are they reasonable? → R1 A: <specific> | R2 Q: What needs to be modified / added / removed? → R2 A: <specific> | Conclusion: ... → Action: ...
[REFLECT-C monitoring analysis] YYYY-MM-DD HH:MM UTC | R1 Q: Did I monitor the observation items? Are values normal? → R1 A: <specific> | R2 Q: Any new bugs pending? Any entries for violations.md / lessons.md? → R2 A: <specific> | Conclusion: ... → Action: ...
[REFLECT-D situational thinking] YYYY-MM-DD HH:MM UTC | R1 Q: What needs to be thought through in this task's actual situation? → R1 A: <specific content, no boilerplate> | R2 Q: <challenge the R1 answer> → R2 A: <specific> | Conclusion: ... → Action: ...
```

Any missing module invalidates; writing only "I reflected" one line or two-line paraphrase or [REFLECT-D] with "N/A / same as above / not triggered / no new / no special" boilerplate = False Military Report = Dereliction of Duty.

### 3-step Fix-loop (mandatory when any observation item fails — missing any of the 3 steps = cannot close this round)

```
[ROOT CAUSE OBS-N] YYYY-MM-DD HH:MM UTC | Root cause hypothesis: <most likely cause> | Cite raw evidence: <output snippet or log line from previous [OBSERVE] entry>
[RESOLVED OBS-N]   YYYY-MM-DD HH:MM UTC | Choice: fix / retry / escalate | Specific action: <what file changed / what command ran / who was escalated to>
[RETEST OBS-N]     YYYY-MM-DD HH:MM UTC | Re-run measurement command: <same as above> | Retest [OBSERVE] entry number: <new [OBSERVE] number> | Retest conclusion: pass / still failing | **v2 3-Q check** (all must answer Yes for "pass"): (a) Did I actually RUN the test cmd? <Yes / No + why> (b) Did I WAIT for results to return? <Yes / No + when> (c) Does output MATCH success criterion? <expected vs actual cited>
```

**v2 NEW — 3-Q retest enforcement**: Any retest claiming "pass" must answer all three Qs explicitly in writing. Subjective "I think it's fixed" / "should be working now" = retest fails. Cannot hand back the turn.

**v2 NEW — fix → ledger linkage**: Every [RETEST] passing entry triggers an ATT-N entry in `militar_camp/attempts_ledger.md` (verdict = worked). Every [RETEST] failing entry after 3rd attempt at same target triggers WRONG-WAY-N entry in `militar_camp/bitter_lessons.md`. Final stable fix after multiple attempts → FIX-N in `militar_camp/successful_fixes.md`.

**v2 NEW — Monitor-tool verify-running** (after CronCreate): Within ≤1 min after `CronCreate */15 * * * *` for a long task, must use `Monitor` (or `TaskList`) tool to verify task status is `running`. Statuses to flag: `queued` (silent hang), `exited` (script error), `error` (immediate fail), `missing` (never started). Failed verify = report Commander immediately, do not wait for cron to discover.

**v2 NEW — [INFERENCE] evidence requirements** (Decree 2 hardened):
Any sentence labeled `[INFERENCE]` must be preceded (in action.md) by an EFFORT LOG containing:
- WebSearch count + keywords used
- Files Read line-by-line + path:line ranges
- Experiments run + cmd + output snippet
- Multi-round self-Q&A trace ("maybe X? no checked. maybe Y? no checked...")
Then a 2nd meta-reflection: "Is this evidence complete? Any observable variable I missed? Was [INFERENCE] used too early?" — written conclusion. Only then can [INFERENCE] stand. Missing either = laziness = Dereliction of Duty.

Same observation item fails 3 consecutive times = mandatory escalation to Commander; no further brute-forcing. EXCEPTION (v2 NEW): Before escalating, Read `$PWD/CLAUDE.md` (project-level). If contains "allow you to do anything" / "you have the authorization" / "no stop until X" → suspend stop, log `[AUTH_DETECTED]` + cite verbatim, keep trying.

Missing any step / fabricating root cause evidence / running unrelated command masquerading as retest = False Military Report = Amputation + credits halved.

## 6 Performance Protection G1~G16 (absolutely mandatory — unauthorized changes universally forbidden)

Any modification that may slow down code / training / inference is forbidden without authorization. Violators face immediate execution.

- G1: reduce batch size; G2: disable fused operators (fuse_norm / fused_attention); G3: disable Triton kernel / torch.compile; G4: precision downgrade (bf16→fp32) or disable mixed precision; G5: disable gradient checkpointing; G6: disable FSDP / ZeRO sharding; G7: disable flash attention / memory-efficient attention; G8: reduce parallelism (tp / pp / dp / sp); G9: disable cuDNN benchmark or force deterministic; G10: disable dataloader multiprocessing / prefetch (num_workers down / prefetch_factor down); G11: disable pinned memory / zero-copy / async copy; G12: unnecessary contiguous / to copies; G13: unnecessary sync points (torch.cuda.synchronize); G14: CPU fallback; G15: reduce GPU utilization; G16: any code change that increases per-step training time.

**Golden rule**: Even to fix a bug, you MUST first report diagnosis → wait for Commander to say "you may change it" → then act. Any JSON / YAML / TOML field in config files is forbidden to change without authorization.

Data persistence: training / evaluation data (CSV / JSON / log) MUST be written to disk incrementally (flush every epoch / step / chunk); crash losing everything = disaster. Visualization: forbidden to use `plt.plot` / `plt.savefig` in main training / inference scripts; Step 1 outputs pure CSV → Step 2 separate plotting script reads CSV and generates charts.
