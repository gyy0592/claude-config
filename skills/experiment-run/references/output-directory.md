# Output Directory Structure

Every run produces a self-contained directory under `{output.root}/` (default: `exp/`). This reference defines the exact layout, naming convention, and code snapshot procedure.

---

## Directory Layout

```
{output.root}/
└── {run.name}_{YYYYMMDD_HHMMSS}_{identifier}/
    ├── config.yaml              # Exact config used for this run (copied at start)
    ├── snapshot/                 # Code at the moment of execution
    ├── logs/
    │   ├── stdout.log           # Standard output (Slurm captures this automatically)
    │   └── stderr.log           # Standard error
    ├── records/
    │   ├── scalars.csv          # Long-format numeric time series (see recording-format.md)
    │   ├── events.jsonl         # Per-item structured logs (see recording-format.md)
    │   └── field_registry.json  # What fields were promised (see recording-format.md)
    ├── artifacts/               # Large outputs: checkpoints, images, plots, tables
    ├── run_manifest.json        # Metadata: command, env, timing, exit code
    └── run_checks.json          # Post-run validation results (see postrun-validation.md)
```

---

## Directory Naming

Format: `{run.name}_{YYYYMMDD_HHMMSS}_{identifier}`

The identifier depends on the backend:
- **Slurm**: `job{SLURM_JOB_ID}_{SLURMD_NODENAME}` — e.g., `bert-finetune_20260406_143022_job12345_node01`
- **Local**: `pid{PID}_{hostname}` — e.g., `bert-finetune_20260406_143022_pid98765_workstation`

### Collision rules

If the directory already exists and is non-empty, **refuse to run**. This prevents accidental overwrites of previous results. Tell the user the directory exists and ask what to do (rename, delete, or skip).

---

## Code Snapshot

Copy the project code into `snapshot/` before execution starts. This ensures the exact code that produced the results is always available, even if the repo changes later.

```bash
rsync -a --exclude='.git' --exclude='__pycache__' --exclude='.cache' \
      --exclude='exp' --exclude='.venv' --exclude='node_modules' \
      "$PROJECT_DIR/" "$EXP_DIR/snapshot/"
```

The exclude list comes from `snapshot.exclude` in the config. Add any large data directories to this list — the snapshot should contain code, not data.

### When to skip snapshot

Set `snapshot.enabled: false` only when:
- The repo is very large (>1GB of code) and rsync would be slow
- The code is versioned and you record the git commit hash in `run_manifest.json` instead

If snapshot is disabled, record the git state in the manifest:
```json
{
  "git_commit": "abc123def",
  "git_branch": "main",
  "git_dirty": false
}
```

---

## run_manifest.json

Created at the start of the run, updated at the end with exit information:

```json
{
  "run_name": "bert-finetune",
  "task_type": "train",
  "command": "python train.py --config config.yaml",
  "config_path": "config.yaml",
  "start_time": "2026-04-06T14:30:22Z",
  "end_time": "2026-04-06T16:45:11Z",
  "duration_seconds": 8089,
  "exit_code": 0,
  "hostname": "node01",
  "job_id": "12345",
  "partition": "gpu",
  "python_version": "3.11.5",
  "gpu_info": "NVIDIA GB200 x8",
  "git_commit": "abc123def",
  "git_branch": "main",
  "git_dirty": false,
  "env_snapshot": {
    "CUDA_VISIBLE_DEVICES": "0,1,2,3",
    "NCCL_DEBUG": "INFO"
  }
}
```

### Fields to capture

| Field | When | How |
|-------|------|-----|
| `run_name`, `task_type`, `command`, `config_path` | Start | From config |
| `start_time` | Start | `datetime.now(timezone.utc).isoformat()` |
| `hostname` | Start | `socket.gethostname()` or `$SLURMD_NODENAME` |
| `job_id` | Start | `$SLURM_JOB_ID` (Slurm only) |
| `partition` | Start | `$SLURM_JOB_PARTITION` (Slurm only) |
| `python_version` | Start | `sys.version` |
| `gpu_info` | Start | `torch.cuda.get_device_name()` if available |
| `git_commit`, `git_branch`, `git_dirty` | Start | `git rev-parse HEAD`, `git branch --show-current`, `git diff --quiet` |
| `env_snapshot` | Start | Selected env vars relevant to the run |
| `end_time`, `duration_seconds`, `exit_code` | End | Updated when the process finishes |

---

## Directory Creation Order

1. Create the run directory and all subdirectories (`logs/`, `records/`, `artifacts/`)
2. Copy `config.yaml` into the run directory
3. Write initial `run_manifest.json` (without end_time/exit_code)
4. Save `field_registry.json` to `records/`
5. Run code snapshot (if enabled)
6. Execute the entrypoint
7. Update `run_manifest.json` with end_time and exit_code
8. Run post-run validation (see postrun-validation.md)
