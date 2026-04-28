# FILL_IN — Placeholder Reference

Replace every `{{PLACEHOLDER}}` in all files under this skill with the real value for your machine.
Run this to find all remaining unfilled placeholders at any time:

```bash
grep -r '{{' ~/.claude/skills/this-cluster-general/
```

---

## Machine Identity

| Placeholder | What to fill in | Example |
|---|---|---|
| `{{HOSTNAME}}` | Output of `hostname` | `brev-xl0m07l3c` |
| `{{SERVER_MODEL}}` | Vendor + model string | `Oracle ORACLE SERVER E4-2c` |
| `{{OS_VERSION}}` | OS name + version | `Ubuntu 24.04.3 LTS (Noble Numbat)` |
| `{{KERNEL_VERSION}}` | Output of `uname -r` | `6.14.0-1016-oracle` |
| `{{MACHINE_ID}}` | `cat /etc/machine-id` | `0771dda86c81452d89db0bf4c9531a81` |
| `{{LAST_VERIFIED_DATE}}` | Date you last verified all facts | `2026-04-22` |

## User / Permissions

| Placeholder | What to fill in | Example |
|---|---|---|
| `{{USERNAME}}` | Your Linux username | `Barry` |
| `{{UID}}` | Your user ID (`id -u`) | `1002` |
| `{{GID}}` | Your group ID (`id -g`) | `1002` |
| `{{USER_GROUPS}}` | Output of `groups` | `Barry sudo nvidia slurm_admin gpuaccess` |

## Python / Venv

| Placeholder | What to fill in | Example |
|---|---|---|
| `{{VENV_PATH}}` | Absolute path to primary venv root | `/home/Barry/Barry` |
| `{{PYTHON_BIN}}` | Absolute path to primary Python interpreter | `/home/Barry/Barry/bin/python` |
| `{{PIP_BIN}}` | Absolute path to primary pip | `/home/Barry/Barry/bin/pip` |
| `{{VENV_ACTIVATE}}` | Absolute path to activate script | `/home/Barry/Barry/bin/activate` |
| `{{PRIMARY_VENV_NAME}}` | Human-readable name for primary venv | `Barry` |
| `{{PYTHON_VERSION}}` | Python version in primary venv | `3.12.3` |
| `{{PYTORCH_VERSION}}` | PyTorch version string | `2.5.1+cu121` |
| `{{CUDA_RUNTIME_VERSION}}` | CUDA version bundled with PyTorch | `12.1` |
| `{{PRIMARY_VENV_KEY_PACKAGES}}` | Key packages + versions in primary venv | `fla 0.4.1, transformers 5.2.0, triton 3.1.0` |
| `{{SECONDARY_VENV_NAME}}` | Name of optional secondary venv (or remove section) | `moe` |
| `{{SECONDARY_PYTHON_BIN}}` | Interpreter path for secondary venv | `/home/Barry/moe/bin/python` |
| `{{SECONDARY_VENV_KEY_PACKAGES}}` | Key packages in secondary venv | `transformers 5.6.2, accelerate, datasets` |
| `{{SECONDARY_VENV_MANAGER}}` | How secondary venv is managed | `uv venv` |

## Storage Paths

| Placeholder | What to fill in | Example |
|---|---|---|
| `{{PROJECT_ROOT}}` | Absolute path to your main project | `/home/Barry/github_repo/linear_attention_flame` |
| `{{SCRATCH_PATH}}` | Fast scratch / NVMe mount | `/lp-dev` |
| `{{SCRATCH_DEVICE}}` | Block device for scratch | `/dev/nvme0n1` |
| `{{SCRATCH_SIZE}}` | Total size of scratch | `6.2T` |
| `{{SCRATCH_FREE}}` | Free space on scratch | `5.9T` |
| `{{BULK_STORAGE_PATH}}` | Large bulk storage mount | `/data` |
| `{{BULK_DEVICE}}` | Block device for bulk storage | `/dev/md127` |
| `{{BULK_SIZE}}` | Total size of bulk storage | `19T` |
| `{{BULK_USED_PCT}}` | Percent used on bulk storage | `89%` |
| `{{ROOT_DEVICE}}` | Block device for `/` | `/dev/sda1` |
| `{{ROOT_SIZE}}` | Total size of root partition | `193G` |
| `{{ROOT_FREE}}` | Free space on root | `42G` |

## Hardware

| Placeholder | What to fill in | Example |
|---|---|---|
| `{{CPU_SPEC}}` | Full CPU description | `2× AMD EPYC 7J13 64-Core @ 2.45 GHz` |
| `{{CORE_COUNT}}` | Physical core / thread count | `128 physical cores / 256 threads` |
| `{{CPU_ONLINE_COUNT}}` | SLURM CPUTot value | `255` |
| `{{NUMA_COUNT}}` | Number of NUMA nodes | `8` |
| `{{RAM_SIZE}}` | Total RAM | `2.0 TiB` |
| `{{SLURM_REAL_MEMORY}}` | SLURM RealMemory value | `2060000M` |
| `{{SWAP_SIZE}}` | Swap size | `127 GiB` |
| `{{GPU_COUNT}}` | Number of GPUs | `8` |
| `{{GPU_MODEL}}` | GPU model name | `NVIDIA A100-SXM4-80GB` |
| `{{GPU_TYPE}}` | SLURM GPU type identifier | `a100` |
| `{{MAX_GPU_COUNT}}` | Max GPUs (same as GPU_COUNT) | `8` |
| `{{GPU_COMPUTE_CAP}}` | CUDA compute capability | `sm_80` |
| `{{GPU_DRIVER_VERSION}}` | NVIDIA driver version | `580.65.06` |
| `{{CUDA_DRIVER_VERSION}}` | CUDA version supported by driver | `13.0` |
| `{{NVCC_PATH}}` | Path to nvcc | `/usr/bin/nvcc` |
| `{{NVCC_VERSION}}` | nvcc release version | `12.0` |

## SLURM

| Placeholder | What to fill in | Example |
|---|---|---|
| `{{SLURM_VERSION}}` | Output of `sinfo --version` | `23.11.4` |
| `{{PARTITION_DEFAULT}}` | Default / long-run partition name | `gpu` |
| `{{PARTITION_DEBUG}}` | Short-test partition name | `debug` |
| `{{PARTITION_ADMIN}}` | Admin-only partition name (optional) | `admin_debug` |
| `{{DEBUG_WALL_TIME}}` | Wall-time limit on debug partition | `1:00:00` |
| `{{EXAMPLE_JOB_ID}}` | A real job ID used for verification | `701` |

## Network / Other

| Placeholder | What to fill in | Example |
|---|---|---|
| `{{OTHER_CLUSTER_NAME}}` | Name of any other cluster you also use (for comparison notes) | `LYX cluster` |
