---
name: this-cluster-general
description: "Reference card for a single-node SLURM GPU server. General template — fill in all {{PLACEHOLDER}} values in FILL_IN.md before use. Use when the user invokes /this-cluster-general, or automatically before: running local commands on this box, submitting/cancelling SLURM jobs, writing sbatch scripts, choosing a Python interpreter, deploying code locally, or reading job logs. Also consult when other skills need local machine facts. Triggers on: /this-cluster-general, sbatch, squeue, scancel, sinfo, SLURM, 本机, 这台机子, 这台服务器, 提交任务, 跑实验, gpu partition, 本地部署, 本地提交."
---

# This Cluster ({{HOSTNAME}}) — Reference Card

> **TEMPLATE**: Replace every `{{PLACEHOLDER}}` with real values before using.
> See [FILL_IN.md](FILL_IN.md) for the full list of values to fill in.

Route to the right sub-skill based on what you are about to do. Read ONLY the relevant reference file — do not load all of them.

**Last verified: {{LAST_VERIFIED_DATE}}**

---

## Sub-skill Router

| When you are about to... | Read this | Why |
|---|---|---|
| Access the machine / check identity / network | [references/connection.md](references/connection.md) | Host facts, user/group membership, SSH access, whether we're already ON the box. Getting this wrong = running local commands as if remote, or vice versa. |
| Run Python or pick an interpreter | [references/python-envs.md](references/python-envs.md) | The primary venv path, which packages are installed, PyTorch+CUDA version. Wrong interpreter = missing packages / wrong torch / broken GPU. |
| Submit, cancel, or monitor a SLURM job | [references/job-submission.md](references/job-submission.md) | SLURM commands, gold-standard sbatch template, partition choices, common pitfalls. Wrong template = wasted GPU hours. |
| Move code or data into/out of this machine | [references/deploy.md](references/deploy.md) | Storage layout, where to put code/data, internet connectivity status. |
| Check hardware specs or node/GPU status | [references/hardware.md](references/hardware.md) | CPU/RAM/GPU specs, disk mounts, SLURM resource view. Required before sizing `--mem` or `--gres`. |

---

## Quick Cheat Sheet

```bash
# We're ALREADY on this machine — no SSH needed for normal work.
hostname              # {{HOSTNAME}}

# Submit a job
sbatch /path/to/script.sbatch

# Check queue
squeue
squeue -u {{USERNAME}}

# Cancel a job
scancel <job_id>

# Node / partition info
sinfo
scontrol show node {{HOSTNAME}}

# Run Python (hardcoded venv path — no activate needed)
{{PYTHON_BIN}} script.py
```

## Canonical Paths

| Thing | Path |
|---|---|
| User home | `/home/{{USERNAME}}` |
| Python venv | `{{VENV_PATH}}` (interpreter: `{{PYTHON_BIN}}`) |
| Main project | `{{PROJECT_ROOT}}` |
| SLURM templates | `/home/{{USERNAME}}/slurm-templates/` |
| Fast NVMe scratch | `{{SCRATCH_PATH}}` ({{SCRATCH_SIZE}}, mostly free) |
| Large bulk storage | `{{BULK_STORAGE_PATH}}` ({{BULK_SIZE}}, check `df -h {{BULK_STORAGE_PATH}}` before writing) |
