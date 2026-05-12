# content/memory/ Index (Read on demand, not always resident in context)

This directory holds long-term lessons + workflow details that are "read on demand, not auto-injected every time". Startup injection is only `<repo>/CLAUDE.md` (**no byte hard limit** — Commander explicitly stated "regardless of cost"); this directory is Read on demand rather than always resident to reduce load. The main router `CLAUDE.md` clearly states at the top "Read content/memory/INDEX.md when needed" (not using `@` auto-import syntax).

## 4 File Trigger Table

| File | Description | Trigger Read Condition |
|------|----|--------------|
| `lessons.md` | Positive lessons (L-XXX + tags) | Before writing comprehensive reflection; citing past "correct practices"; `tags:` grep at session start |
| `violations.md` | Violation list + charge quick reference + execution ritual (W-XXX + tags) | Suspecting a red line; Commander pointing out violation; before writing violation triple-item set; `tags:` grep at session start |
| `workflows.md` | 4-step workflow + long-task monitoring + debugging + entry format | Writing / running code / starting long tasks / debugging / listing indicators / writing [OBSERVE]/[reflection] / 3-step fix-loop |
| `soldier_protocol.md` | Dispatching + autonomy + Private iron rules (A)~(G) + silence + 4-element question checklist | Before dispatching; before writing Agent prompt; before filling soldier_status.md authorization; before multiple-choice questions |

## Don't know which to read → grep tags

`grep -lE "tags:.*<tag>" content/memory/*.md`. Common tags: `scope-creep` / `over-design` / `language-violation` / `concept-confusion` / `flow-skip` / `memory-blind` / `fatigue` / `recitation-shortcut` / `dead-link` / `plan-gap` / `listen-comprehension` / `premature-answer` / `codex-overtrust`.

## Migration Rules (v3 triple-review hard constraints)

Migration to v2 requires all entries to have `tags:` lines. Entries without `tags:` do not count toward session self-check coverage (naturally excluded when grep-ing); need to add `tags:` first to restore coverage. Each W-XXX / L-XXX must contain: title + behavior/consequence/correct practice (W) or correct behavior/lesson/specific example (L) + `tags:`. Missing any one = invalid.

## Mandatory Closing: One of Two Options (must do at the end of the task when writing the final section of action.md)

(a) Append new entries to `violations.md` (W-XXX) or `lessons.md` (L-XXX) (with `tags:`); or (b) explicitly write "[no new lessons]". Not writing = Dereliction of Duty precursor.
