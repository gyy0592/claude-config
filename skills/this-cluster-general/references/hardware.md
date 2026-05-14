# Hardware

## Single-Node Machine

This is **one** physical box, not a multi-node cluster. SLURM is configured as a one-node scheduler so that resource arbitration (multiple concurrent jobs / agents) still works. All partitions (`{{PARTITION_DEFAULT}}`, `{{PARTITION_DEBUG}}`, `{{PARTITION_ADMIN}}`) point to the same node.

## Node Specs — `{{HOSTNAME}}`

| Property | Value |
|----------|-------|
| Vendor / model | `{{SERVER_MODEL}}` |
| Architecture | x86_64 |
| OS | `{{OS_VERSION}}` |
| Kernel | `{{KERNEL_VERSION}}` |
| CPU | `{{CPU_SPEC}}` |
| Cores / threads | `{{CORE_COUNT}}` |
| NUMA | `{{NUMA_COUNT}}` NUMA nodes |
| RAM | **`{{RAM_SIZE}}`** (`{{SLURM_REAL_MEMORY}}` reported by SLURM) |
| Swap | `{{SWAP_SIZE}}` |
| GPU | **`{{GPU_COUNT}}× {{GPU_MODEL}}`** |
| GPU compute capability | `{{GPU_COMPUTE_CAP}}` |
| GPU driver | `{{GPU_DRIVER_VERSION}}` |
| CUDA (driver) | `{{CUDA_DRIVER_VERSION}}` |
| `nvcc` | `{{NVCC_PATH}}`, release `{{NVCC_VERSION}}` |

> PyTorch bundles its own CUDA runtime (currently `cu{{CUDA_RUNTIME_VERSION}}` — {{CUDA_RUNTIME_VERSION}}), so the `nvcc` version mismatch with the driver is harmless for PyTorch users.

## Storage

| Path | Device | Size | Used | Free | Notes |
|------|--------|------|------|------|-------|
| `/` | `{{ROOT_DEVICE}}` | `{{ROOT_SIZE}}` | — | **`{{ROOT_FREE}}`** | System + user home — don't write big outputs here |
| `{{SCRATCH_PATH}}` | `{{SCRATCH_DEVICE}}` | `{{SCRATCH_SIZE}}` | — | **`{{SCRATCH_FREE}}`** | **Best for datasets / checkpoints** — fast storage |
| `{{BULK_STORAGE_PATH}}` | `{{BULK_DEVICE}}` | `{{BULK_SIZE}}` | `{{BULK_USED_PCT}}` | — | Bulk storage, **check before writing** |
| `/tmp` | tmpfs | — | — | — | RAM-backed, use for scratch |

## GPU Layout (verified {{LAST_VERIFIED_DATE}}, `nvidia-smi`)

```
GPU 0  {{GPU_MODEL}}
GPU 1  {{GPU_MODEL}}
...
GPU {{MAX_GPU_COUNT-1}}  {{GPU_MODEL}}
```

> Fill in the actual PCIe addresses from `nvidia-smi -L`. If using SXM4/NVLink, confirm topology with `nvidia-smi topo -m` before planning multi-GPU all-reduce-heavy runs.

## SLURM Resource View

```
# scontrol show node {{HOSTNAME}}
CPUTot={{CPU_ONLINE_COUNT}}  Gres=gpu:{{GPU_TYPE}}:{{MAX_GPU_COUNT}}  RealMemory={{SLURM_REAL_MEMORY}}  State=IDLE
Partitions={{PARTITION_DEFAULT}},{{PARTITION_DEBUG}},{{PARTITION_ADMIN}}
```

Per-partition caps:

| Partition | Wall-time limit | Pool |
|-----------|-----------------|------|
| `{{PARTITION_DEFAULT}}` (default) | infinite | all {{MAX_GPU_COUNT}} GPUs |
| `{{PARTITION_DEBUG}}` | `{{DEBUG_WALL_TIME}}` | all {{MAX_GPU_COUNT}} GPUs |
| `{{PARTITION_ADMIN}}` | infinite | all {{MAX_GPU_COUNT}} GPUs (admin-only) |

## Practical Sizing Guidance

- **Small probe / sanity run**: `--partition={{PARTITION_DEBUG}} --gres=gpu:{{GPU_TYPE}}:1 --mem=32G --cpus-per-task=8 --time=0:15:00`
- **Single-GPU training**: `--partition={{PARTITION_DEFAULT}} --gres=gpu:{{GPU_TYPE}}:1 --mem=128G --cpus-per-task=16 --time=12:00:00`
- **Full {{MAX_GPU_COUNT}}-GPU DDP**: `--partition={{PARTITION_DEFAULT}} --ntasks-per-node={{MAX_GPU_COUNT}} --gres=gpu:{{GPU_TYPE}}:{{MAX_GPU_COUNT}} --cpus-per-task=16` (leave headroom out of {{RAM_SIZE}})
- Leave at least 1 CPU / 40 G RAM headroom for SLURM + OS.

## Known Quirks

> Fill in any machine-specific quirks discovered during verification:
- *(e.g., one CPU offline, storage nearly full, partition quirks, etc.)*
- `{{BULK_STORAGE_PATH}}` may be nearly full — always check `df -h {{BULK_STORAGE_PATH}}` before large writes.
- `/home` free space is limited — route big outputs to `{{SCRATCH_PATH}}`.
