# Gen Draft — Phase 1: Gather Context

Your only job in this phase is to understand the task well enough to write a correct draft. Do not write the draft yet.

## What you need to know

Work through this checklist. For each item, check if the current conversation already answers it. If yes, extract it. If no, add it to your question list.

- [ ] **Goal** — what does this task achieve, in one sentence?
- [ ] **Inputs** — what data/APIs/files go in? Format? Source?
- [ ] **Outputs** — what deliverables come out? Described by content, not filename.
- [ ] **Observable outputs** — what should the user see DURING execution? (metrics, logs, intermediate artifacts) — users often forget this, always ask explicitly
- [ ] **Constraints** — any non-negotiable rules? (performance, cost, compatibility, format)
- [ ] **Skill reads** — are there skills or docs that must be loaded at specific trigger points during execution?
- [ ] **Destructive operations** — any irreversible actions (delete, overwrite, force-push) that need user confirmation?
- [ ] **Known facts** — any prior experiments, verified results, or failed approaches to record?
- [ ] **Decision points** — any trade-offs with no obvious answer that the user needs to weigh in on?

## Special case: experiment / training tasks

If the task involves training, fine-tuning, evaluation, hyperparameter search, or any work producing **one output directory per run**, you MUST ask about run directory naming BEFORE writing the draft. Use `AskUserQuestion` with `multiSelect: true`:

```
Question: "What should be encoded in the run directory name?"
Options:
  - Model / task identity  (e.g. "deltanet_sst")
  - Key hyperparameters    (e.g. "t0.1_bs32_lr5e4")
  - Hardware info          (e.g. "4xgb200")
  - Node / cluster ID      (e.g. "node11")
  - Scheduler job ID       (e.g. "j7131")
  - Date / timestamp       (e.g. "20260405")
```

## How to ask

Collect all missing items into a single `AskUserQuestion` call. Do not ask one question at a time.

- Use `multiSelect: true` when the user needs to pick from a list
- Use open-ended format for items that need free-text answers
- Group related questions together

**Do not ask about things already answered in the conversation.** Extract those silently.

## When you are done

You are done with Phase 1 when you have sent the `AskUserQuestion` call and the user has replied. Now go back to `SKILL.md` and proceed to Phase 2.
