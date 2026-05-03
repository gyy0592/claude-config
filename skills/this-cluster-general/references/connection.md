# Connection

## You Are Already On This Machine

Claude Code runs **locally on this box**. There is no SSH hop, no tunnel, no jump host for normal work. Just run commands directly with `Bash`.

```bash
hostname    # {{HOSTNAME}} — confirms identity
```

## Host Facts

| Property | Value |
|----------|-------|
| Hostname | `{{HOSTNAME}}` |
| Chassis / vendor | `{{SERVER_MODEL}}` |
| OS | `{{OS_VERSION}}` |
| Kernel | `{{KERNEL_VERSION}}` |
| Machine ID | `{{MACHINE_ID}}` |
| Architecture | `x86_64` |

## User / Permissions

| Property | Value |
|----------|-------|
| User | `{{USERNAME}}` (uid={{UID}}, gid={{GID}}) |
| Home | `/home/{{USERNAME}}` |
| Groups | `{{USER_GROUPS}}` |
| `sudo` | Yes — `{{USERNAME}}` is in the `sudo` group. Use sparingly. |
| SLURM | Full `sbatch` / `scancel` / `scontrol` rights (via `slurm_admin`) |
| GPU | `nvidia` + `gpuaccess` membership → unrestricted `nvidia-smi`, direct CUDA |

## Network

| Target | Reachable | Verified |
|---|---|---|
| `github.com` | ✅ HTTP 200 | {{LAST_VERIFIED_DATE}} |
| `pypi.org` | ✅ HTTP 200 | {{LAST_VERIFIED_DATE}} |

Consequence: `pip install`, `git clone`, HuggingFace downloads, `wandb` sync all work directly.

> **Note**: If your cluster is air-gapped, update the table above and remove the pip/HuggingFace notes.

## Remote SSH In (if ever needed)

If the user wants to reach this box from their laptop, they would configure an SSH alias pointing at this machine's public address. Not relevant for Claude Code sessions, which always run locally on the host.
