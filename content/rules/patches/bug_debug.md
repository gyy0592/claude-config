---
id: P-002
created: 2026-05-14T00:00:00Z
source: human
scope: global
applies_to:
  state: [EXECUTE_LOOP, REFLECT]
  scenario: bug_code
  triggers:
    - keyword: ["error", "exception", "traceback", "OOM", "killed", "crash", "hang", "anomaly", "fail", "unexpected"]
    - tool: Bash
      cmd_regex: "pytest|unittest|python.*test_|cargo test|go test"
priority: 100
status: active
---

## what

Force reproduce-before-fix discipline; escalate REFLECT to 2 rounds (not the default 1-on-anomaly) once 3 anomalies accrue inside an EXECUTE_LOOP.

## why

- Patch-and-pray fixes mask root cause; a confirmed reproducer is the only ground truth that the fix actually fixes anything (W-003).
- 3-anomaly threshold matches workflow_config.yaml `execute_loop.failure_budget` already; this patch tightens the REFLECT round count when that budget triggers.

## how

1. **Reproducer first** — before any code edit:
   - Capture minimal repro command + expected vs actual output in action.md under `[REPRO]`.
   - Save raw failing log to `workspace/<task>/repro_<ts>.log` (or ledger equivalent).
2. **One variable at a time** — between repro runs, change exactly one knob; record under `[VAR=<name> from <old> to <new>]` in action.md.
3. **3-anomaly escalation** — when execute_loop_audit.sh reports anomaly count ≥ 3:
   - `transition.sh EXECUTE_EXIT --reason=bug-3anomaly`
   - REFLECT cycle uses N=2 rebuttal rounds minimum (not the on-anomaly single round).
4. **Fix discipline** — after a candidate fix lands:
   - Re-run the saved repro command. The 3-question retest gate (ran cmd? waited for results? matched success criterion?) must all answer YES before claiming `[FIX_CONFIRMED]`.

## examples

CUDA OOM in train.py: capture `python train.py --bs 32` traceback → bisect `--bs` to 16 → confirm fix by re-running with bs=16 AND bs=32 both observed. Do NOT call it fixed after only running bs=16.
