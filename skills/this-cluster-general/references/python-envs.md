# Python Environments

## Environment Manager

> Fill in: does this machine use `conda`, plain `venv`, `uv`, or a mix? Update sections below accordingly.

## Available Environments

| Env | Python | Absolute Path | PyTorch | CUDA | Key Packages |
|-----|--------|--------------|---------|------|-------------|
| **{{PRIMARY_VENV_NAME}}** (venv) | {{PYTHON_VERSION}} | `{{PYTHON_BIN}}` | {{PYTORCH_VERSION}} | {{CUDA_RUNTIME_VERSION}} | {{PRIMARY_VENV_KEY_PACKAGES}} |
| **{{SECONDARY_VENV_NAME}}** ({{SECONDARY_VENV_MANAGER}}) | {{PYTHON_VERSION}} | `{{SECONDARY_PYTHON_BIN}}` | {{PYTORCH_VERSION}} | {{CUDA_RUNTIME_VERSION}} | {{SECONDARY_VENV_KEY_PACKAGES}} |
| System | — | `/usr/bin/python3` | — | — | Do not use — system Python, don't pollute |

> **Optional**: Remove the secondary venv row if you only have one environment.

### When to use which env

| Task | Use env |
|------|---------|
| *(fill in your main task type)* | **{{PRIMARY_VENV_NAME}}** |
| *(fill in secondary task type, or remove row)* | **{{SECONDARY_VENV_NAME}}** |

### Verified missing ({{LAST_VERIFIED_DATE}}) — install via pip if needed

- *(list any packages you know are missing but may be needed)*

## How to Use Python

### Recommended — hardcoded absolute path

No `source activate` needed. The project's `CLAUDE.md` enforces this path:

```bash
PYTHON={{PYTHON_BIN}}
$PYTHON train.py --config configs/xxx.yaml
```

### Interactive — activate the venv

```bash
source {{VENV_ACTIVATE}}
python train.py ...
deactivate
```

## Installing Packages

This machine has outbound internet (github + pypi reachable — see `connection.md`). `pip install` works:

```bash
{{PIP_BIN}} install <package>
```

Per the user's global rule: **no auto-install**. If a script hits `ModuleNotFoundError`, surface the missing package as an error and pause — do not silently pip-install.

## Verified

GPU + PyTorch confirmed working ({{LAST_VERIFIED_DATE}}, SLURM job {{EXAMPLE_JOB_ID}} on partition `{{PARTITION_DEBUG}}`):
```
torch={{PYTORCH_VERSION}}, cuda=True, device_count={{GPU_COUNT}} ({{GPU_MODEL}}, {{GPU_COMPUTE_CAP}})
```

## Rules

- Always use the full absolute path `{{PYTHON_BIN}}` in sbatch scripts — don't rely on `PATH` or `source activate` inside SLURM.
- Do not create new envs without the user explicitly asking.
- PyTorch is compiled against CUDA {{CUDA_RUNTIME_VERSION}} runtime; the driver supports up to CUDA {{CUDA_DRIVER_VERSION}}, so torch + nvcc {{NVCC_VERSION}} both work.
