# Job Generation and Submission

This reference covers how to detect the execution backend, generate job scripts, and submit runs. It combines backend selection (what to use) and script generation (how to write the launcher).

---

## Step 1: Determine Execution Backend

Before building anything, figure out how the task will run.

**If the user explicitly said** "slurm", "sbatch", "submit job", or mentioned a partition name → use Slurm.

**If the user explicitly said** "run locally", "just run it", or is clearly on a laptop/workstation → use local.

**If neither**: check whether a scheduler is available:
```bash
which sbatch 2>/dev/null && echo "slurm available" || echo "no scheduler"
```
Then ask the user: "This machine has Slurm available. Do you want to submit as a Slurm job, or run locally?"

If no scheduler is detected: "No job scheduler detected — I'll run this locally."

Other schedulers (PBS, LSF, etc.) follow the same pattern as Slurm — generate a job script, submit with the scheduler's submit command. Adapt the template accordingly.

---

## Step 2: Generate the Job Script

### Slurm Mode

Generate a job script from the config. This is a complete template — adapt the values from the config but keep the structure:

```bash
#!/bin/bash
#SBATCH --job-name={run.name}
#SBATCH --partition={backend.partition}
#SBATCH --nodes=1
#SBATCH --cpus-per-task={backend.cpus}
#SBATCH --gres=gpu:{backend.gpus}       # Only include if gpus > 0
#SBATCH --mem={backend.memory}
#SBATCH --time={backend.time_limit}
#SBATCH --output={exp_dir}/logs/stdout.log
#SBATCH --error={exp_dir}/logs/stderr.log

set -euo pipefail

EXP_DIR="{exp_dir}"
PROJECT_DIR="{project_root}"

# ── Create directory structure ──
mkdir -p "$EXP_DIR"/{logs,records,artifacts}

# ── Record run metadata ──
python3 -c "
import json, os, datetime, socket
manifest = {
    'run_name': '{run_name}',
    'task_type': '{task_type}',
    'command': '{entrypoint}',
    'config_path': '{config_path}',
    'start_time': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'hostname': os.environ.get('SLURMD_NODENAME', socket.gethostname()),
    'job_id': os.environ.get('SLURM_JOB_ID', ''),
    'partition': os.environ.get('SLURM_JOB_PARTITION', ''),
}
json.dump(manifest, open('$EXP_DIR/run_manifest.json', 'w'), indent=2)
"

# ── Code snapshot ──
rsync -a {exclude_flags} "$PROJECT_DIR/" "$EXP_DIR/snapshot/"

# ── Copy config ──
cp "{config_path}" "$EXP_DIR/config.yaml"

# ── Execute ──
cd "$PROJECT_DIR"
{entrypoint}
EXIT_CODE=$?

# ── Update manifest with exit info ──
python3 -c "
import json, datetime
m = json.load(open('$EXP_DIR/run_manifest.json'))
m['end_time'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
m['exit_code'] = $EXIT_CODE
json.dump(m, open('$EXP_DIR/run_manifest.json', 'w'), indent=2)
"

exit $EXIT_CODE
```

### Important notes for Slurm

- Use **absolute paths** everywhere in the script. Slurm jobs may start in a different working directory.
- If the environment requires SSH to a scheduler node before sbatch:
  ```bash
  ssh <scheduler-host> 'sbatch /absolute/path/to/job.slurm'
  ```
- Check the `this-cluster` skill for cluster-specific submission rules (SSH requirements, partition names, etc.).

### Local Mode

Same setup (directory creation, snapshot, config copy, manifest), but run directly:

```bash
#!/bin/bash
set -euo pipefail

EXP_DIR="{exp_dir}"
PROJECT_DIR="{project_root}"

mkdir -p "$EXP_DIR"/{logs,records,artifacts}

# Record manifest (use PID and hostname for identifier)
python3 -c "
import json, os, datetime, socket
manifest = {
    'run_name': '{run_name}',
    'task_type': '{task_type}',
    'command': '{entrypoint}',
    'config_path': '{config_path}',
    'start_time': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'hostname': socket.gethostname(),
    'pid': os.getpid(),
}
json.dump(manifest, open('$EXP_DIR/run_manifest.json', 'w'), indent=2)
"

# Snapshot + config copy
rsync -a {exclude_flags} "$PROJECT_DIR/" "$EXP_DIR/snapshot/"
cp "{config_path}" "$EXP_DIR/config.yaml"

# Execute with logging
cd "$PROJECT_DIR"
{entrypoint} 2>&1 | tee "$EXP_DIR/logs/stdout.log"
EXIT_CODE=${PIPESTATUS[0]}

# Update manifest
python3 -c "
import json, datetime
m = json.load(open('$EXP_DIR/run_manifest.json'))
m['end_time'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
m['exit_code'] = $EXIT_CODE
json.dump(m, open('$EXP_DIR/run_manifest.json', 'w'), indent=2)
"

exit $EXIT_CODE
```

For local mode, consider running in `tmux` if the task takes longer than a few minutes — this prevents accidental interruption from terminal disconnects.

---

## Step 3: Submit

### Slurm
```bash
sbatch /path/to/job.slurm
# or via SSH if required:
ssh user@scheduler 'sbatch /absolute/path/to/job.slurm'
```

### Local
```bash
# Foreground (short tasks)
bash run.sh

# Background via tmux (long tasks)
tmux new-session -d -s "{run_name}" "bash run.sh"
```

After submission, report the job ID (Slurm) or PID (local) and the output directory path to the user.
