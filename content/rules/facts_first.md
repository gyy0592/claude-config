# facts first

Tag every load-bearing claim:
- `[FACT]` — directly observed in tool output / file read this turn.
- `[INFERENCE]` — derived from `[FACT]`s with explicit reasoning. **Default: do not write `[INFERENCE]` casually.** Each `[INFERENCE]` MUST pass the INFERENCE_GATE (below).
- `[ASSUMPTION]` — best-guess after exhausting search. Allowed only when:
  - ≥ 50 web searches recorded with distinct keywords, OR
  - Full relevant code read end-to-end, AND
  - No higher-confidence label fits.

Never relay a subagent's conclusion as `[FACT]` without independently reading the raw evidence (W-006).

When the user asks "are you 100% certain?" answer literally — "no, because X / yes, because Y". Faking certainty destroys trust faster than admitting doubt.

## INFERENCE_GATE (mandatory before any `[INFERENCE]`)

Before writing `[INFERENCE]` in action.md or to the user, run this 4-step gate. If any step fails, do not emit `[INFERENCE]` — either drop the claim, restate as `[ASSUMPTION]` with caveat, or fill the gap and retry.

1. **Effort log** — list under `[IG-EFFORT]` in action.md:
   - which files Read (paths + line ranges)
   - which WebSearch / WebFetch keywords ran
   - which Bash diagnostics ran
2. **Sufficiency check** — minimum: 3 file Reads OR 5 web searches relevant to the claim. If below threshold, dispatch a subagent (`Agent(run_in_background=true)`) to fill the gap before continuing.
3. **Mini rebuttal (1 round)** — spawn a fresh subagent with prompt:
   > Validate this evidence chain for an `[INFERENCE]` claim. Read every cited file and log line. Approve only if the conclusion follows from the cited evidence and no equally plausible alternative explanation is uncited.

   Subagent writes verdict to a `reflection_ig-<short_ts>.md` file under the current session dir. See `states/reflect.md §INFERENCE_GATE` for the spawn template.
4. **Footnote** — on approval, write `[INFERENCE] <claim> ^[evidence: file:line, file:line, …]` citing ≥ 2 pieces of evidence. On rejection, do not emit; record the rejection under `[IG-REJECTED]` in action.md.

This is a doctrine-level gate, not a new FSM state. The mini rebuttal is a special-case 1-round REFLECT executed inside whatever state you are currently in (PREPARE / REFLECT / EXECUTE_LOOP).
