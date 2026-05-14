# Deploying Code & Data

## Internet Connectivity

This box has full outbound internet (`github.com`, `pypi.org`, HuggingFace, `wandb` all reachable — verified {{LAST_VERIFIED_DATE}}). That means:

- `git clone`, `git pull`, `git push` — all work directly on this box
- `pip install` — works, installs into `{{VENV_PATH}}/`
- `wandb login` + online sync — work
- HuggingFace `datasets.load_dataset(...)` / `AutoModel.from_pretrained(...)` — work

No `rsync` dance needed to get code onto the machine, because Claude Code **is running on the machine** already.

> **Note**: If your cluster is air-gapped, update this section and remove the direct-install notes.

## Canonical Directory Layout

```
/home/{{USERNAME}}/                              # User home (on {{ROOT_DEVICE}}, {{ROOT_SIZE}}, {{ROOT_FREE}} free — watch space!)
├── {{PRIMARY_VENV_NAME}}/                       # Python venv (site-packages here)
├── github_repo/
│   └── <main-project>/                          # Main project (= {{PROJECT_ROOT}})
│       ├── artifacts/                           # Per-task logs, per-agent workspaces
│       │   ├── _project/                        #   shared project state
│       │   └── task_<name>/                     #   one dir per task/agent
│       ├── configs/ src/ scripts/ ...
│       └── train.py
├── slurm-templates/                             # Reusable sbatch templates
├── papers/  arxiv_papers/                       # Paper reading workspace
└── scripts/                                     # Miscellaneous helper scripts

{{BULK_STORAGE_PATH}}/                           # {{BULK_DEVICE}} — {{BULK_SIZE}}, ~{{BULK_USED_PCT}} FULL. Check df -h before writing.
{{SCRATCH_PATH}}/                                # {{SCRATCH_DEVICE}} — {{SCRATCH_SIZE}}, ~{{SCRATCH_FREE}} free. Best scratch / dataset cache.
```

## Where to Put What

| What | Go here | Why |
|------|---------|-----|
| Source code | `/home/{{USERNAME}}/github_repo/<repo>/` | Visible to git, small, safe to keep on `/` |
| Per-run artifacts (logs, metrics, ckpts) | `<repo>/artifacts/task_<name>/` | Matches the user's mandatory artifacts layout (CLAUDE.md) |
| Large datasets | `{{SCRATCH_PATH}}/{{USERNAME}}/datasets/` | **DEFAULT for all large data** — fast random I/O, {{SCRATCH_FREE}} free |
| Big checkpoints (>10 GB each) | `{{SCRATCH_PATH}}/{{USERNAME}}/checkpoints/` | **DEFAULT for all checkpoints** — don't fill `/home` (only {{ROOT_FREE}} free) |
| Bulk cold data | `{{BULK_STORAGE_PATH}}/{{USERNAME}}/` | Last resort only — {{BULK_SIZE}} but **{{BULK_USED_PCT}} full**, always `df -h {{BULK_STORAGE_PATH}}` first |
| Scratch / tmp | `/tmp` (tmpfs, RAM-backed) | For short-lived files only |
| SLURM stdout/stderr | `<repo>/artifacts/task_<name>/slurm_%j.out` | See `job-submission.md` template |

## Workflow — Typical Local Run

```bash
# 1. Code already lives in {{PROJECT_ROOT}} — edit in place.
cd {{PROJECT_ROOT}}

# 2. Submit a job
sbatch scripts/submit.sh

# 3. Monitor
squeue -u {{USERNAME}}
tail -F artifacts/task_<name>/slurm_<jobid>.out

# 4. Pull / push via git as normal
git add -p
git commit -m "msg"
git push
```

## Disk-Space Warnings

- `/` (`/home`) has only **{{ROOT_FREE}} free out of {{ROOT_SIZE}}**. Do NOT write big outputs under `/home/{{USERNAME}}/` — redirect to `{{SCRATCH_PATH}}/`.
- `{{BULK_STORAGE_PATH}}` is **{{BULK_USED_PCT}} full** — writes may fail with `ENOSPC`. Always `df -h {{BULK_STORAGE_PATH}}` before planning a big write.
- `{{SCRATCH_PATH}}` (fast storage) is the recommended target for datasets and checkpoints.

## If You Ever Need to Push Code From Elsewhere

This box is reachable via SSH over whatever alias `{{USERNAME}}` has configured. Not relevant for Claude Code sessions — they always run locally. Use `git push`/`git pull` against GitHub instead of `rsync` for code sync.
