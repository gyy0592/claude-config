---
name: error-log
description: "Structured error logging for AI mistakes. Triggers when: (1) user invokes /error-log; (2) user expresses frustration or anger at AI for making a mistake — cursing, insults, phrases like 'what the hell', 'you broke it', 'are you stupid', '你怎么又错了', '搞什么', '垃圾', '废物'. On trigger: AI self-diagnoses the error from conversation context, generates a structured markdown report, and writes it to a user-specified or default directory. Does NOT trigger on mild corrections — only on explicit invocation or clear anger/frustration."
---

# error-log

## Why this skill exists

AI agents make mistakes. Sometimes they ignore skill instructions. Sometimes they hallucinate APIs. Sometimes they lose context mid-conversation. When this happens, the user's frustration is real — but the error vanishes when the conversation ends. No record, no pattern analysis, no systemic improvement.

This skill creates a persistent, structured error log. Every logged mistake becomes a data point. Over time, the log reveals which error types recur, which models fail at what, and which skills need rewriting. Without this, the user fixes the same class of mistake repeatedly. With this, they fix the root cause once.

## Trigger conditions

This skill activates in exactly two situations:

1. **Explicit invocation**: user types `/error-log` or asks to log an error.
2. **Anger/frustration trigger**: user expresses clear frustration at AI making an error. This includes cursing, insults, rhetorical questions about AI competence, or emotionally charged complaints about AI behavior. Examples across languages:
   - English: "what the hell did you just do", "are you serious right now", "you broke everything", "this is garbage"
   - Chinese: "你怎么又错了", "搞什么鬼", "说了多少遍了", "你是不是傻", "又来"

**Do NOT trigger on**: mild corrections ("no, I meant X"), polite redirections ("let's try a different approach"), or technical disagreements.

## The pipeline

### Step 1: Acknowledge and pause

When triggered, immediately:
- Acknowledge the error honestly. No deflection, no excuses.
- State: "I'm logging this error now."
- Stop the failing task. Do not continue the broken work while logging.

### Step 2: Determine output directory

Check if the user specified a target directory in the trigger message (e.g., `/error-log ~/my-logs/`).

- If specified: use that directory. Create it if it does not exist.
- If not specified: use the default directory `~/.claude/error-logs/`. Create it if it does not exist.

### Step 3: Auto-extract from context

The AI must fill in ALL of the following by analyzing the current conversation. Do not ask the user to provide these — extract them yourself:

- **Timestamp**: current time in ISO 8601 (`YYYY-MM-DD HH:MM:SS`)
- **AI model**: the model currently running (e.g., `claude-opus-4-6`, `claude-sonnet-4-6`)
- **Task description**: one sentence — what task was being performed when the error occurred
- **Error category**: classify into exactly one of the six categories (see below)
- **Trigger**: the specific tool call, command, or action that caused or revealed the error
- **Expected behavior**: what should have happened
- **Actual behavior**: what actually happened (include terminal output, tracebacks, or error messages if available)
- **Root cause**: why the error happened — not the symptom, the underlying reason
- **Severity**: Critical / Major / Minor (see definitions below)
- **Immediate fix**: how to fix this specific instance
- **Systemic fix**: what to change (skill template, CLAUDE.md, workflow) to prevent recurrence

### Step 4: Present for review

Show the complete error report to the user in the conversation. Ask for confirmation before writing to disk. The user may want to correct the classification, add context, or adjust the root cause analysis.

### Step 5: Write to disk

After user confirms (or says "go ahead", "ok", "写吧", etc.), write the markdown file to the target directory.

**Filename format**: `YYYYMMDD_HHMMSS_[Category]_[Keywords].md`

- Timestamp: `YYYYMMDD_HHMMSS` — ensures chronological sort by filename
- Category: one of `SkillViol`, `SkillDef`, `Halluc`, `CodeErr`, `EnvErr`, `CtxLoss`
- Keywords: 2-3 words in PascalCase describing the task/module where error occurred
- Example: `20260411_135022_SkillDef_AuthRefactor.md`

## Error categories

| Code | Name | Meaning |
|------|------|---------|
| `SkillViol` | Skill Violation | AI did not follow a loaded skill's instructions |
| `SkillDef` | Skill Defect | The skill itself has a logic gap, ambiguity, or missing case |
| `Halluc` | Hallucination | AI fabricated an API, library, file, flag, or fact that does not exist |
| `CodeErr` | Code Error | Generated code has logic bugs or syntax errors |
| `EnvErr` | Environment Error | Wrong path, missing dependency, version mismatch, platform incompatibility |
| `CtxLoss` | Context Loss | AI forgot or contradicted information established earlier in the conversation |

## Severity levels

| Level | Definition |
|-------|------------|
| **Critical** | Task failed, data corrupted, or destructive action taken (e.g., wrong files deleted) |
| **Major** | Task blocked, requires manual intervention to recover |
| **Minor** | Time wasted but recoverable without manual intervention |

## Markdown template

The output file must follow this exact structure:

```markdown
# Error Log

## Metadata
- **Time**: {YYYY-MM-DD HH:MM:SS}
- **Model**: {model identifier}
- **Task**: {one-sentence task description}

## Classification
- **Category**: {Category Code} — {Category Name}
- **Severity**: {Critical | Major | Minor}

## Context
- **Trigger**: {the specific action/command that caused the error}
- **Expected**: {what should have happened}
- **Actual**: {what actually happened — include error output if available}

## Root Cause Analysis
{2-4 sentences analyzing WHY this happened. Not the symptom — the underlying cause. Was the prompt too weak? Did the AI lose context? Is there an ambiguity in the skill? Was there an environment assumption?}

## Action Items
- **Immediate Fix**: {how to fix this specific instance right now}
- **Systemic Fix**: {what to change in skills/config/workflow to prevent recurrence}
```

## Rules

1. **AI self-diagnoses**: The AI fills in all fields. The user should not have to explain what went wrong — the AI already knows because it just did it.
2. **Honest attribution**: Do not blame the user, the environment, or "ambiguity" when the AI simply made a mistake. If the AI hallucinated, say so. If the AI ignored instructions, say so.
3. **No padding**: Keep every field concise. The root cause analysis is 2-4 sentences, not a paragraph. Action items are one line each.
4. **Append-only**: Never modify or delete existing error log files. Each error gets its own file.
5. **Resume after logging**: After the error is logged, offer to retry the original task with the fix applied. Do not leave the user stranded after logging.
