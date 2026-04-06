# Pre-flight Confirmation

Before executing anything, show the user a summary of what will happen and what will be recorded. This is the last checkpoint before potentially expensive computation starts — it catches mistakes, missing fields, and misunderstandings.

---

## What to Show

Display this summary and wait for explicit confirmation:

```
═══════════════════════════════════════════
  Pre-flight Check
═══════════════════════════════════════════

  Run name:       {run.name}
  Task type:      {run.task_type}
  Description:    {run.description}
  Entrypoint:     {run.entrypoint}
  Backend:        {backend.type} ({backend.partition})
  Resources:      {backend.cpus} CPUs, {backend.gpus} GPUs, {backend.memory} RAM
  Time limit:     {backend.time_limit}

  Output dir:     {output.root}/{dir_name}/

  Scalar metrics (→ scalars.csv, for plotting):
    ✓ {field_1}
    ✓ {field_2}
    ...

  Per-item fields (→ events.jsonl):
    ✓ {field_a}
    ✓ {field_b}
    ...

  Artifacts (→ artifacts/):
    ✓ {artifact_1}
    ...

  Code snapshot:  {yes/no}
  Record interval: every {N} items or {T} seconds

  Anything missing? Confirm to proceed.
═══════════════════════════════════════════
```

---

## Why Each Section Matters

- **Run name + description**: catches "oh wait, I named it wrong" before it becomes a confusing directory name you're stuck with.
- **Backend + resources**: catches "I wanted 4 GPUs not 1" or "that partition has a 1-hour limit, this needs 6 hours".
- **Scalar metrics list**: this is the most important part. The user sees exactly what will appear in their plots. If they realize they forgot `grad_norm` or `eval_loss`, they can add it now instead of after a 10-hour training run.
- **Per-item fields**: same idea for events.jsonl. Missing fields here means missing data for per-sample analysis.
- **Artifacts**: confirms that checkpoints, plots, etc. will be saved.
- **Code snapshot**: rare to skip, but good to confirm.
- **"Anything missing?"**: explicitly prompts the user to think about what they'll want later. This single question prevents the most common experiment regret.

---

## What to Check Automatically

Before showing the summary, verify these conditions and warn if any fail:

| Check | Warning |
|-------|---------|
| Output directory already exists | "Directory already exists. Contents will NOT be overwritten — the run will abort. Delete it first or change the run name." |
| `backend.gpus > 0` but no GPU-related scalar fields | "You're using GPUs but not recording gpu_memory_allocated. Want to add it?" |
| `task_type: train` but no `loss` in scalar_fields | "This is a training run but `loss` is not in scalar_fields. Are you sure?" |
| `task_type: eval` but no primary metric in scalar_fields | "This is an evaluation run but no accuracy/F1/metric field is declared. What's the primary metric?" |
| `backend.time_limit` seems short for the task | "Time limit is {X}. Is that enough for {task_type} with this config?" |
| `snapshot.enabled: false` and no git info | "Code snapshot is disabled and I can't find a git commit. There will be no way to recover the exact code used." |

---

## After Confirmation

Once the user confirms:

1. Save the confirmed field list to `records/field_registry.json` (see recording-format.md)
2. Proceed to output directory setup (see output-directory.md)
3. Generate and submit the job (see job-generation.md)

Do **not** proceed until the user explicitly confirms. A simple "ok", "yes", "go", "lgtm" counts as confirmation. If the user modifies anything, regenerate the summary with the changes and confirm again.
