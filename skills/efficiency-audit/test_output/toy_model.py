"""toy_model.py — intentionally inefficient toy PyTorch model for efficiency-audit self-test.

Inefficiency on display: DataLoader with num_workers=0 + a __getitem__ that sleeps to simulate slow disk.
The audit should detect that data loading is the bottleneck and the fix (num_workers=4 +
persistent_workers=True) is what sub-skill 4 validates.

CPU-only. No GPU required.

Run a SELF-CONTAINED timing experiment (2 warmup epochs dropped, 5 measured epochs, median):
    python toy_model.py --mode=before   # num_workers=0 (slow)
    python toy_model.py --mode=after    # num_workers=4 + persistent (fast)

Output last line:  "mode=<m> samples_s=[...] median_s=<X.XXXX>"

The warmup + measured-loop runs INSIDE ONE Python process, so:
  - torch import cost is paid once
  - persistent_workers actually pays off (workers survive across measured epochs)
This makes the parallelization speedup observable on a tiny synthetic dataset.
"""
from __future__ import annotations

import argparse
import os
import statistics
import time
from typing import Tuple

try:
    import torch
    import torch.nn as nn
    from torch.utils.data import Dataset, DataLoader
    HAVE_TORCH = True
except ImportError:
    HAVE_TORCH = False


# Tunables. Total per-epoch sleep ≈ NUM_SAMPLES * SLEEP_PER_SAMPLE_S = 4.0 s.
# That is large enough that 4-worker parallelism wins handily even after fork overhead.
SLEEP_PER_SAMPLE_S = 0.02
NUM_SAMPLES = 200
INPUT_DIM = 32
OUTPUT_DIM = 10
BATCH_SIZE = 16
N_WARMUP = 2
N_RUNS = 5


if HAVE_TORCH:

    class SlowDataset(Dataset):
        """Each sample takes SLEEP_PER_SAMPLE_S seconds to load. Mimics slow disk / decode."""

        def __init__(self, n: int = NUM_SAMPLES) -> None:
            self.n = n

        def __len__(self) -> int:
            return self.n

        def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor]:
            time.sleep(SLEEP_PER_SAMPLE_S)
            x = torch.randn(INPUT_DIM)
            y = torch.tensor(idx % OUTPUT_DIM, dtype=torch.long)
            return x, y

    class ToyMLP(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.net = nn.Sequential(
                nn.Linear(INPUT_DIM, 64),
                nn.ReLU(),
                nn.Linear(64, OUTPUT_DIM),
            )

        def forward(self, x: torch.Tensor) -> torch.Tensor:
            return self.net(x)


def make_loader(num_workers: int, persistent_workers: bool) -> "DataLoader":
    if not HAVE_TORCH:
        raise RuntimeError("PyTorch required")
    ds = SlowDataset()
    pw = persistent_workers and num_workers > 0
    return DataLoader(
        ds,
        batch_size=BATCH_SIZE,
        num_workers=num_workers,
        persistent_workers=pw,
        pin_memory=False,
        shuffle=False,
    )


def run_one_epoch(loader, model, loss_fn, optim) -> float:
    t0 = time.perf_counter()
    for x, y in loader:
        out = model(x)
        loss = loss_fn(out, y)
        optim.zero_grad()
        loss.backward()
        optim.step()
    return time.perf_counter() - t0


def measure(mode: str) -> Tuple[float, list]:
    """Run N_WARMUP+N_RUNS epochs with the requested config. Drop warmups; return median + all samples."""
    if mode == "before":
        loader = make_loader(num_workers=0, persistent_workers=False)
    elif mode == "after":
        cpu = max(1, min(4, os.cpu_count() or 2))
        loader = make_loader(num_workers=cpu, persistent_workers=True)
    else:
        raise ValueError(mode)
    model = ToyMLP()
    model.train()
    loss_fn = nn.CrossEntropyLoss()
    optim = torch.optim.SGD(model.parameters(), lr=1e-3)
    # warmup (dropped)
    for _ in range(N_WARMUP):
        run_one_epoch(loader, model, loss_fn, optim)
    # measured
    samples = [run_one_epoch(loader, model, loss_fn, optim) for _ in range(N_RUNS)]
    return statistics.median(samples), samples


def main() -> int:
    if not HAVE_TORCH:
        print("torch not installed; cannot run benchmark.")
        return 2
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("before", "after"), default="before")
    args = parser.parse_args()
    med, samples = measure(args.mode)
    samples_str = "[" + ", ".join(f"{s:.4f}" for s in samples) + "]"
    print(f"mode={args.mode} samples_s={samples_str} median_s={med:.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
