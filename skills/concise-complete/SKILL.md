---
name: concise-complete
description: Rewrites any passage to maximize information density while losing zero information. Every sentence becomes as short as it can be, yet keeps full subject, verb, and object, and carries no ambiguous references. Use as the final language-level pass inside paper-reader and any writing-heavy skill, and use it standalone whenever the user complains that text is "too wordy", "bloated", "unclear", "ambiguous", wants "tighter" / "denser" / "no filler" writing, or says things like "rewrite this more concisely", "kill the filler", "max info density". Domain-agnostic — works on any prose, in any language.
---

# concise-complete

## Why this skill exists

Most writing is padded. Filler phrases ("it should be noted that", "in order to", "as a matter of fact"), hedging ("perhaps", "may possibly"), empty connectors, and vague pronouns ("this", "it") eat the reader's attention without adding meaning. Strip them and the text gets faster. But strip them *too aggressively* and you drop the subject, the verb, or the object, and the sentence becomes ambiguous or ungrammatical. This skill walks the narrow line between the two: **maximum information entropy, zero information loss**.

## The two rules (both must hold)

1. **Minimize length.** Delete every word that does not carry meaning. Collapse multi-word phrases into single words where possible. Replace vague pronouns with their concrete antecedent whenever the antecedent is even slightly ambiguous.
2. **Preserve every information bit.** Never drop a subject, verb, object, modifier, quantifier, or qualifier that changes meaning. Never drop a hedge that actually expresses uncertainty ("we believe" stays when the claim is genuinely tentative; it goes when the author was just hedging politely).

If the two rules conflict — keep the information. The skill is called concise-**complete**, not concise-only.

## Things to always cut

- Filler openers: "It is important to note that", "As mentioned earlier", "Needless to say", "Basically", "Essentially", "In essence".
- Hedging-as-politeness: "might perhaps possibly", "somewhat kind of", "a bit of a".
- Tautologies: "final outcome", "advance planning", "end result", "first and foremost".
- Empty connectors: "Furthermore", "Moreover" (if the logical link is already clear).
- Nominalizations that waste verbs: "make a decision" → "decide", "provide an explanation" → "explain", "give consideration to" → "consider".

## Things to never cut

- Subject, verb, or object of any clause.
- Quantifiers and scope words: "all", "some", "at most", "for every", "∃".
- Numerical values, units, signs, and their bounds.
- Technical qualifiers that change truth: "almost", "asymptotically", "in expectation", "up to a constant".
- Uncertainty markers that reflect genuine doubt.

## The ambiguity rule

The words "this", "it", "that", "they", "the former", "the latter" are allowed only when the antecedent is unambiguous in the **immediately preceding clause**. If the antecedent is even one sentence back, or if more than one candidate antecedent exists, replace the pronoun with the concrete noun.

**Bad:** "We run gradient descent for 100 steps. After the warmup, it drops sharply."
**Good:** "We run gradient descent for 100 steps. After the warmup, the loss drops sharply."

## Self-check pass (do this on every rewritten paragraph)

After rewriting, re-read each sentence and ask:

1. Can I delete any word without changing meaning? (If yes, delete.)
2. Does every sentence have a clear subject, verb, and — where needed — object?
3. Does every "this / it / that / they" point to exactly one thing in the previous clause?
4. Did I accidentally drop a quantifier, number, unit, or qualifier?

If any answer is wrong, fix it before finishing.

## How other skills invoke this

When `paper-reader`, `contrib-extract`, `pipeline-walk`, or `math-explain` finishes a chunk, they hand the chunk's prose to this skill for a final language pass. The skill returns the rewritten chunk and a short list of the edits it made, so the caller can show the pass to the user (per the visible-self-check rule).

## Standalone usage

When the user says things like "tighten this", "make this denser", "kill the filler", just apply the rules above to the text they gave you and return the rewritten version plus a brief list of the categories of edits you made.
