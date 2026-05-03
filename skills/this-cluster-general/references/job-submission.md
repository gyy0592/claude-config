# Job Submission (SLURM {{SLURM_VERSION}})

## Commands

All in `/usr/bin/`. `{{USERNAME}}` has direct `sbatch` / `scancel` / `scontrol` rights (member of `slurm_admin`).

| Command | Purpose |
|---------|---------|
| `sbatch script.sbatch` | Submit a job |
| `squeue` | View full queue |
| `squeue -u {{USERNAME}}` | Your jobs only |
| `squeue -j <job_id>` | Specific job |
| `scontrol show job <job_id>` | Detailed job info |
| `scancel <job_id>` | Cancel a job |
| `sinfo` | Partition / node state |
| `scontrol show node {{HOSTNAME}}` | Full node view (GPU count, mem, state) |
| `sacct -j <job_id>` | Post-mortem accounting (exit code, runtime, memory) |

## Partitions

| Partition | Default? | Time limit | GPUs available | Use |
|-----------|:-------:|------------|----------------|-----|
| **`{{PARTITION_DEFAULT}}`** | ✅ yes | infinite | `gpu:{{GPU_TYPE}}:{{MAX_GPU_COUNT}}` | Real training / long runs |
| `{{PARTITION_DEBUG}}` | — | `{{DEBUG_WALL_TIME}}` | `gpu:{{GPU_TYPE}}:{{MAX_GPU_COUNT}}` | Short tests, probes, sanity checks. Hits wall-time after limit. |
| `{{PARTITION_ADMIN}}` | — | infinite | `gpu:{{GPU_TYPE}}:{{MAX_GPU_COUNT}}` | Admin-only; avoid unless explicitly needed |

All partitions point to the **same single node** `{{HOSTNAME}}` — SLURM here is really a scheduler-on-one-box, not a multi-node cluster. Use partition choice to self-classify the job (long-running vs ephemeral).

## Logs

SLURM's stdout/stderr delivery is native on this box — just specify `--output` / `--error` paths and they land where you said.

## Gold Standard sbatch Template (single GPU)

```bash
#!/bin/bash
#SBATCH --job-name=[CHANGE: job-name]
#SBATCH --partition={{PARTITION_DEFAULT}}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:{{GPU_TYPE}}:1
#SBATCH --mem=64G
#SBATCH --time=[CHANGE: HH:MM:SS]
#SBATCH --output={{PROJECT_ROOT}}/artifacts/[CHANGE: task_name]/slurm_%j.out
#SBATCH --error={{PROJECT_ROOT}}/artifacts/[CHANGE: task_name]/slurm_%j.err

set -euo pipefail

echo "Job $SLURM_JOB_ID on $(hostname) at $(date -Iseconds)"
echo "GPUs visible: $CUDA_VISIBLE_DEVICES"
cd "$SLURM_SUBMIT_DIR"

# ── Python (hardcoded venv path, no activate needed) ─────────────────────
PYTHON={{PYTHON_BIN}}
export PYTHONUNBUFFERED=1

# ── Main command ─────────────────────────────────────────────────────────
$PYTHON [CHANGE: your_script.py --arg1 val1]

echo "Job finished at $(date -Iseconds)"
```

## Multi-GPU Template (torchrun on {{GPU_COUNT}}× {{GPU_MODEL}})

```bash
#!/bin/bash
#SBATCH --job-name=[CHANGE: job-name]
#SBATCH --partition={{PARTITION_DEFAULT}}
#SBATCH --nodes=1
#SBATCH --ntasks-per-node={{GPU_COUNT}}          # one task per GPU
#SBATCH --gres=gpu:{{GPU_TYPE}}:{{MAX_GPU_COUNT}}
#SBATCH --cpus-per-task=16
#SBATCH --mem=400G
#SBATCH --time=[CHANGE: HH:MM:SS]
#SBATCH --output=/home/{{USERNAME}}/.../logs/%j_%x.out
#SBATCH --error=/home/{{USERNAME}}/.../logs/%j_%x.err

set -euo pipefail
echo "Job $SLURM_JOB_ID on $(hostname) — GPUs=$CUDA_VISIBLE_DEVICES"
cd "$SLURM_SUBMIT_DIR"

PYTHON={{PYTHON_BIN}}
export PYTHONUNBUFFERED=1

torchrun --standalone --nproc_per_node=$SLURM_NTASKS_PER_NODE \
    [CHANGE: train.py --config configs/xxx.yaml]

echo "End: $(date -Iseconds)"
```

## Template Rules

### Allowed modifications

| Field | Allowed Values |
|-------|---------------|
| `--job-name` | Any string, no spaces |
| `--partition` | `{{PARTITION_DEFAULT}}` (long runs) or `{{PARTITION_DEBUG}}` (≤{{DEBUG_WALL_TIME}} tests) |
| `--gres` | `gpu:{{GPU_TYPE}}:N` where `1 ≤ N ≤ {{MAX_GPU_COUNT}}` |
| `--cpus-per-task` | Up to ~32 per GPU sensible; node has {{CPU_ONLINE_COUNT}} usable CPUs |
| `--mem` | Up to ~{{SLURM_REAL_MEMORY}}; node has {{RAM_SIZE}} |
| `--time` | `HH:MM:SS`. On `{{PARTITION_DEBUG}}`, must be ≤ `{{DEBUG_WALL_TIME}}` |
| `--output` / `--error` | Any absolute path under `/home/{{USERNAME}}/` |
| `PYTHON=` | `{{PYTHON_BIN}}` (see python-envs.md) |
| Main command | Any valid command using `$PYTHON` or `torchrun` |

### Forbidden

- Submitting to `{{PARTITION_ADMIN}}` unless the user explicitly asks (admin-reserved).
- Specifying `--nodes >1` — only one physical node exists.
- `--gres=gpu:{{GPU_TYPE}}:N` with `N>{{MAX_GPU_COUNT}}` — only {{GPU_COUNT}} GPUs on the box.
- Wall-time longer than `{{DEBUG_WALL_TIME}}` on the `{{PARTITION_DEBUG}}` partition.
- Relative paths in `--output` / `--error` — always absolute.
- Removing `set -euo pipefail` or `PYTHONUNBUFFERED=1`.
- Hardcoded `conda activate` inside sbatch unless conda is confirmed present.

## Submission from this machine

Just run `sbatch` directly — we're already on the node:

```bash
# Submit
sbatch /absolute/path/to/script.sbatch

# Monitor
squeue -u {{USERNAME}}
watch -n 5 squeue

# Tail the log live
tail -F /path/to/slurm_<job>.out

# Cancel
scancel <job_id>

# Post-mortem
sacct -j <job_id> --format=JobID,JobName,State,Elapsed,MaxRSS,ExitCode
```

## Verified

Probe job `{{EXAMPLE_JOB_ID}}` ({{LAST_VERIFIED_DATE}}, partition `{{PARTITION_DEBUG}}`):
- Submit-to-complete in <10 s
- `--gres=gpu:{{GPU_TYPE}}:1` → `CUDA_VISIBLE_DEVICES=0`, 1× {{GPU_MODEL}} visible
- `torch.cuda.is_available() = True`, `device_count = 1`
- `--output` / `--error` files delivered correctly
