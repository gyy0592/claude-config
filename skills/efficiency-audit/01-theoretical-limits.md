---
name: efficiency-audit-theoretical-limits
description: Sub-skill 1 of efficiency-audit. Compute the theoretical GPU/CPU/IO/memory ceilings of the current machine and emit theoretical_limits.yaml. Use before pipeline analysis so that estimated demand has something to compare against.
---

# Sub-skill 1 — Theoretical limits of THIS machine

## Prerequisites

- This sub-skill is the entry point. No prior outputs required.
- Tools used: `nvidia-smi` (optional), `lscpu`, `nproc`, `dd`, `df`, `mount`. All commands are non-blocking and complete in seconds.

## Goal

Produce `report/efficiency/theoretical_limits.yaml` containing the published-peak performance of each resource on this machine. Downstream sub-skills compare actual demand against these ceilings to spot bottlenecks.

## Commands and how to read them

### 1. GPU

```bash
# Card model + memory
nvidia-smi --query-gpu=name,memory.total,utilization.gpu,utilization.memory --format=csv,noheader 2>/dev/null

# Unique card models (for multi-GPU boxes)
nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sort -u
```

If `nvidia-smi` is missing or returns no GPUs, set the GPU section in the YAML to `gpu: {available: false}` and continue with CPU + IO only.

**Card → peak performance lookup table** (vendor-published, FP16/BF16 tensor cores when applicable; cite the source spec sheet):

| Card                  | FP32 TFLOPS | FP16/BF16 TFLOPS (tensor) | HBM/GDDR bandwidth (GB/s) | Memory (GB) |
| --------------------- | ----------- | ------------------------- | ------------------------- | ----------- |
| NVIDIA A100 40GB SXM4 | 19.5        | 312                       | 1555                      | 40          |
| NVIDIA A100 80GB SXM4 | 19.5        | 312                       | 2039                      | 80          |
| NVIDIA H100 80GB SXM5 | 67          | 989 (sparse: 1979)        | 3350                      | 80          |
| NVIDIA H100 80GB PCIe | 51          | 756 (sparse: 1513)        | 2000                      | 80          |
| NVIDIA H200           | 67          | 989 (sparse: 1979)        | 4800                      | 141         |
| NVIDIA V100 32GB SXM2 | 15.7        | 125                       | 900                       | 32          |
| NVIDIA V100 16GB SXM2 | 15.7        | 125                       | 900                       | 16          |
| NVIDIA RTX 4090       | 82.6        | 165 (tensor 330 sparse)   | 1008                      | 24          |
| NVIDIA RTX 3090       | 35.6        | 71 (tensor 142 sparse)    | 936                       | 24          |
| NVIDIA RTX A6000      | 38.7        | 77 (tensor 155 sparse)    | 768                       | 48          |
| NVIDIA L40            | 90.5        | 181 (tensor 362 sparse)   | 864                       | 48          |
| NVIDIA L40S           | 91.6        | 183 (tensor 366 sparse)   | 864                       | 48          |
| NVIDIA T4             | 8.1         | 65                        | 320                       | 16          |
| NVIDIA RTX A5000      | 27.8        | 55.6 (tensor 111 sparse)  | 768                       | 24          |
| NVIDIA RTX 5090       | 104.8       | 209 (tensor 419 sparse)   | 1792                      | 32          |

**If the detected card is not in the table**: write `UNKNOWN — fill in manually` for FP16/FP32 cells. Look up the spec on the vendor's product page later. Don't fabricate numbers.

### 2. CPU

```bash
# Model + core count + freq + cache
lscpu | grep -E "Model name|^CPU\(s\)|MHz|cache"

# Logical core count
nproc

# Single-line model name
cat /proc/cpuinfo | grep "model name" | head -1
```

**Estimated peak GFLOPS (FP32, AVX/AVX2/AVX-512 aware)**:

```
peak_gflops_fp32 = physical_cores × base_freq_GHz × FMA_ops_per_cycle × vector_width

where FMA_ops_per_cycle = 2 (one FMA = 2 FLOPs), and vector_width depends on ISA:
  - SSE     →  4 (128-bit / 32-bit)
  - AVX/AVX2 →  8 (256-bit / 32-bit)
  - AVX-512 → 16 (512-bit / 32-bit)
```

Check ISA support with `lscpu | grep -i 'flags'`. Most modern x86 CPUs support AVX2; server-class chips (Skylake-X+, Ice Lake, Sapphire Rapids, Zen 4) support AVX-512.

Record both the peak and the realistic sustained throughput (~60–70% of peak for non-trivial workloads).

### 3. IO

```bash
# Pick the directory the user's code writes outputs to. Default to the repo root.
TARGET_DIR="${TARGET_DIR:-$PWD}"

# Sequential write throughput, 512 MB, direct (bypasses page cache)
dd if=/dev/zero of="$TARGET_DIR/.iotest" bs=1M count=512 oflag=direct 2>&1 | tail -1
rm -f "$TARGET_DIR/.iotest"

# Filesystem type
df -T "$TARGET_DIR" | tail -1

# Mount options (look for noatime, nodiratime, async, NFS opts, etc.)
mount | grep "$(df --output=source "$TARGET_DIR" | tail -1)"
```

If `oflag=direct` fails (some filesystems reject it), retry without it but note that the result includes page-cache effects.

**Typical reference numbers** (use as sanity check, not ground truth):

| Storage           | Sequential write | Random 4k write IOPS |
| ----------------- | ---------------- | -------------------- |
| NVMe Gen4 SSD     | 3–7 GB/s         | 100k–1M              |
| NVMe Gen3 SSD     | 2–3 GB/s         | 50k–500k             |
| SATA SSD          | 400–550 MB/s     | 10k–100k             |
| 7200 RPM HDD      | 100–200 MB/s     | 100–200              |
| NFS (10 GbE)      | 300–1100 MB/s    | varies a lot         |
| Lustre/GPFS       | varies (100s of MB/s to multi GB/s) | varies |

### 4. Memory bandwidth (best effort)

```bash
# Requires sudo, may not be available
sudo dmidecode -t memory 2>/dev/null | grep -E "Speed:|Type:|Manufacturer:" | head -20

# Fallback: derive from lscpu / proc/meminfo
cat /proc/meminfo | grep -E "MemTotal|MemAvailable"
lscpu | grep -i 'cache'
```

If dmidecode fails, estimate from CPU spec: DDR4-3200 dual-channel ≈ 51.2 GB/s; DDR5-4800 dual-channel ≈ 76.8 GB/s; DDR5-5600 8-channel server ≈ 358 GB/s. Mark `memory_bandwidth_GB_s` as `estimated` in the YAML.

## YAML output schema

Save to `report/efficiency/theoretical_limits.yaml`:

```yaml
machine: <hostname or "current-machine">
collected_at: <YYYY-MM-DD HH:MM UTC>

gpu:
  available: true
  cards:
    - model: "NVIDIA A100 80GB SXM4"
      count: 8
      fp32_tflops: 19.5
      fp16_bf16_tflops_tensor: 312
      memory_GB: 80
      memory_bandwidth_GB_s: 2039
      source: "NVIDIA A100 datasheet, Apr 2021"
      note: ""

cpu:
  model: "AMD EPYC 7763 64-Core Processor"
  physical_cores: 64
  logical_cores: 128
  base_freq_GHz: 2.45
  isa_vector_width_fp32: 8       # AVX2
  peak_gflops_fp32: 1254
  sustained_gflops_fp32_est: 880  # ~70% of peak
  note: ""

io:
  target_dir: "/home/user/project"
  sequential_write_GB_s: 2.7
  filesystem: "ext4"
  mount_options: "rw,relatime"
  reference_class: "NVMe Gen3 SSD"
  note: ""

memory:
  total_GB: 512
  bandwidth_GB_s: 358
  bandwidth_source: "estimated from DDR5-5600 8-channel"
  note: ""

interpretation:
  green_threshold_pct: 70
  red_alarm: "No resource >=70% saturated → speedup is mathematically possible"
```

## Text summary for the user

After writing the YAML, also emit a 5-line summary in the chat / report:

```
Machine ceilings (this box):
  GPU:    8x A100 80GB → 8x312 = 2496 TFLOPS BF16 ; 8x2039 = 16312 GB/s HBM
  CPU:    64-core EPYC 7763 → ~1.25 TFLOPS FP32 sustained
  IO:     2.7 GB/s sequential write (NVMe Gen3 SSD class)
  Memory: 512 GB total, ~358 GB/s bandwidth
```

This summary becomes the masthead of the final report (sub-skill 5).

## Edge cases

- **No GPU**: write `gpu: {available: false}`. The audit then focuses on CPU + IO; this is the only case where the red-alarm logic checks 2 resources instead of 3.
- **Multi-GPU heterogeneous box** (rare): list each unique card model with its count. The pipeline analysis (sub-skill 2) will pick whichever cards the user's code actually touches.
- **Mixed-precision capable card** (e.g., A100): record both FP32 and BF16/FP16 numbers. The downstream demand estimate will pick the right one based on whether the user's code uses `autocast` / AMP / `bfloat16`.
- **dd permission denied** on `/dev/zero` (extremely rare in containers): use `head -c 512M /dev/urandom > .iotest` instead.

## Done condition

`report/efficiency/theoretical_limits.yaml` exists, contains numeric values for at least one of {gpu, cpu, io}, and parses as valid YAML. Move on to sub-skill 2.
