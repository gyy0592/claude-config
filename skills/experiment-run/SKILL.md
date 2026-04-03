---
name: experiment-run
description: "Manage experiment submission with config-driven parameters, structured output directories, code snapshots, real-time CSV recording, and pre-flight confirmation. Use this skill whenever the user wants to run an experiment, submit a job, 跑实验, 提交任务, launch a training/eval/processing task, or set up a reproducible run — even if they don't explicitly say 'experiment'. Also trigger when the user asks to sbatch, submit slurm, 起任务, or 跑一下."
---

# Experiment Run Skill

When a user asks you to run any code task (training, evaluation, data processing, inference, analysis, or anything else), follow this workflow to ensure the run is config-driven, reproducible, and well-recorded.

The core idea: every run should be a self-contained capsule in `exp/` that a stranger could pick up months later and fully understand what was run, with what parameters, what code, and what happened.

---

## Step 1 — Build or Load the Config

Every run needs a config file (YAML or JSON). If the user doesn't provide one, generate a template from their request and ask them to confirm.

The config has two parts: **fixed structure** (same for all tasks) and **task-specific params** (user defines freely).

### Fixed structure

```yaml
run:
  name: ""              # Names the output directory. Keep it short and descriptive.
  description: ""       # One line: what this run does and why.
  task_type: ""          # train / eval / process / infer / analyze / other
  entrypoint: ""         # The command to execute, e.g. "python -m my_module" or "bash run.sh"

backend:
  type: "slurm"          # slurm / local
  partition: "short"     # Slurm partition (ignored if local)
  time_limit: "02:00:00"
  cpus: 4
  gpus: 0               # 0 = no GPU needed
  memory: "16G"

snapshot:
  enabled: true
  exclude: [".git", "__pycache__", ".cache", "exp", ".venv", "node_modules"]

output:
  root: "exp"            # Output root relative to project directory
```

### Task-specific params

```yaml
params:
  # User puts whatever they need here. Examples:
  #   learning_rate: 3e-4
  #   model_path: "/data/checkpoints/step-1000"
  #   input_file: "data/test.jsonl"
  # The skill makes zero assumptions about these fields.

recording:
  scalar_fields: []       # Numeric values to track in scalars.csv (for plotting)
  intermediate_fields: [] # Per-item fields to log in events.jsonl
  artifact_fields: []     # Large outputs saved as files in artifacts/
  interval_rows: 50       # Aggregate snapshot every N items
  interval_seconds: 60    # Or every N seconds, whichever comes first
```

The reason every parameter lives in the config (not hardcoded in scripts) is reproducibility: someone reading `config.yaml` in the output directory should know exactly what was run without reading the code.

---

## Step 2 — Pre-flight Confirmation

Before executing anything, show the user a summary of what will happen and what will be recorded. This catches mistakes early and ensures nothing important is missed.

### What to show

```
═══════════════════════════════════════════
  Pre-flight Check
═══════════════════════════════════════════

  Run name:       {run.name}
  Task type:      {run.task_type}
  Entrypoint:     {run.entrypoint}
  Backend:        {backend.type} ({backend.partition})

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
  Aggregate interval: every {N} items or {T} seconds

  Anything missing? Confirm to proceed.
═══════════════════════════════════════════
```

The point of asking "anything missing?" is that users often forget to record things they'll want later. Better to ask now than to rerun a 10-hour job because you didn't log gradient norms.

Save the confirmed field list to `records/field_registry.json` so there's a record of what was promised.

Do not proceed until the user confirms.

---

## Step 3 — Set Up the Output Directory

Create the output directory with this structure:

```
{output.root}/
└── {run.name}_{YYYYMMDD_HHMMSS}_{identifier}/
    ├── config.yaml              # Exact config used for this run
    ├── snapshot/                 # Code at the moment of execution
    ├── logs/
    │   ├── stdout.log
    │   └── stderr.log
    ├── records/
    │   ├── scalars.csv          # Long-format numeric time series
    │   ├── events.jsonl         # Per-item structured logs
    │   └── field_registry.json  # What fields were promised
    ├── artifacts/               # Large outputs (weights, images, tables)
    ├── run_manifest.json        # Metadata: command, env, timing, exit code
    └── run_checks.json          # Post-run validation results
```

### Directory naming

`{run.name}_{YYYYMMDD_HHMMSS}_{identifier}` where identifier is:
- Slurm: `job{SLURM_JOB_ID}_{SLURMD_NODENAME}`
- Local: `pid{PID}_{hostname}`

If the directory already exists and is non-empty, refuse to run. This prevents accidental overwrites.

### Code snapshot

Copy the project code into `snapshot/` before execution starts:

```bash
rsync -a --exclude='.git' --exclude='__pycache__' --exclude='.cache' \
      --exclude='exp' --exclude='.venv' --exclude='node_modules' \
      "$PROJECT_DIR/" "$EXP_DIR/snapshot/"
```

This ensures the exact code that produced the results is always available, even if the repo changes later.

---

## Step 4 — Generate and Submit the Job

### Slurm mode

Generate a job script from the config:

```bash
#!/bin/bash
#SBATCH --job-name={run.name}
#SBATCH --partition={backend.partition}
#SBATCH --nodes=1
#SBATCH --cpus-per-task={backend.cpus}
#SBATCH --gres=gpu:{backend.gpus}       # Only if gpus > 0
#SBATCH --time={backend.time_limit}
#SBATCH --output={exp_dir}/logs/stdout.log
#SBATCH --error={exp_dir}/logs/stderr.log

set -euo pipefail

EXP_DIR="{exp_dir}"
PROJECT_DIR="{project_root}"

mkdir -p "$EXP_DIR"/{logs,records,artifacts}

# Record run metadata
python3 -c "
import json, os, datetime
json.dump({
    'job_id': os.environ.get('SLURM_JOB_ID',''),
    'node': os.environ.get('SLURMD_NODENAME',''),
    'partition': os.environ.get('SLURM_JOB_PARTITION',''),
    'start_time': datetime.datetime.now().isoformat(),
    'command': '{entrypoint}',
    'config': '{config_path}',
}, open('$EXP_DIR/run_manifest.json','w'), indent=2)
"

# Code snapshot
rsync -a {exclude_flags} "\$PROJECT_DIR/" "\$EXP_DIR/snapshot/"

# Config copy
cp "{config_path}" "\$EXP_DIR/config.yaml"

# Execute
cd "\$PROJECT_DIR"
{entrypoint}
```

If the environment requires `ssh user@host` before sbatch, use absolute paths:
```bash
ssh user@127.0.0.1 'sbatch /absolute/path/to/job.slurm'
```

### Local mode

Same setup (snapshot, config copy, manifest), but run directly in the shell. Use PID and hostname for the identifier.

---

## Step 5 — Runtime Recording Rules

These rules apply to the task code itself. When writing or modifying the entrypoint code, ensure it follows these patterns:

### scalars.csv — for plotting

Long format so any task can use the same file:

```csv
timestamp,step,phase,field,value
2026-04-03T15:01:00Z,1,train,loss,2.345
2026-04-03T15:01:00Z,1,train,lr,3e-4
```

- `step`: iteration/batch/sample number (meaning depends on task)
- `phase`: stage name (train/eval/test/process/etc)
- `field`: metric name
- `value`: numeric value

Every scalar is appended immediately on production — no buffering until the end. Use file locks if concurrent writes are possible.

### events.jsonl — per-item details

One JSON line per processed item/step, containing all intermediate fields declared in the config. Written immediately, not buffered.

Large values (>1KB strings, arrays) should be truncated in events.jsonl and saved in full to `artifacts/`.

### Recording philosophy

Record generously. It's cheap to write an extra column; it's expensive to rerun a job because you didn't log something you needed. If in doubt, record it.

But be practical: tensors and large arrays should be summarized into scalar stats (mean, max, norm) for scalars.csv. Save raw data to artifacts/ only when specifically needed.

---

## Step 6 — Post-run Checks

After the task finishes, validate the outputs and write `run_checks.json`:

Checks to run (adapt to the task):
1. events.jsonl is non-empty
2. scalars.csv is non-empty (if scalar fields were declared)
3. No NaN/Inf values in scalars
4. All fields from field_registry.json are present in events
5. Process exited with code 0
6. If expected count is known (sample count, step count), actual count matches

If any check fails, print `[CHECK] FAILED` to stdout.

---

## Rules That Apply to Every Run

- **No hardcoding**: every parameter comes from config. If you catch yourself writing a magic number in a script, put it in the config instead.
- **Flush on write**: all record files flush after every write. If the job crashes, you keep everything written so far.
- **Immutable outputs**: once a run directory is complete, never modify existing files in it. You may append summary/check files.
- **Directory collision = abort**: if the output directory exists and is non-empty, stop and tell the user.
- **No silent drops**: if a record can't be written (permission error, disk full), fail loudly rather than silently skipping.
- **Config is the truth**: anyone should be able to read `config.yaml` and `run_manifest.json` in the output directory and fully understand what was run.
