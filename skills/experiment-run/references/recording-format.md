# Recording Format

This reference defines the exact file formats for runtime recording. When writing or modifying any entrypoint code that logs metrics, follow these formats precisely — downstream plotting and analysis tools depend on them.

---

## scalars.csv — Time-Series Metrics (for plotting)

Long format so any task can use the same file and the same plotting code:

```csv
timestamp,step,phase,field,value
2026-04-03T15:01:00Z,1,train,loss,2.345
2026-04-03T15:01:00Z,1,train,lr,3e-4
2026-04-03T15:01:01Z,1,train,grad_norm,12.7
2026-04-03T15:02:00Z,100,train,loss,1.892
2026-04-03T15:10:00Z,1000,eval,accuracy,0.734
```

### Column definitions

| Column | Type | Description |
|--------|------|-------------|
| `timestamp` | ISO 8601 UTC | When this value was recorded. Use `datetime.datetime.now(datetime.timezone.utc).isoformat()`. |
| `step` | int | Iteration/batch/sample number. Meaning depends on the task — for training it's the global step, for eval it might be the sample index. |
| `phase` | string | Stage name: `train`, `eval`, `test`, `process`, `infer`, etc. Allows filtering by phase when plotting. |
| `field` | string | Metric name. Must match one of the `scalar_fields` declared in config. Use snake_case. |
| `value` | float | Numeric value. No strings, no NaN (if a value is undefined, skip the row rather than writing NaN). |

### Writing rules

- **Append immediately** on production — no buffering until the end. Every time you compute a metric, write it to the CSV right away.
- **Flush after every write**. Use `file.flush()` or open in unbuffered/line-buffered mode. If the job crashes, you keep everything written so far.
- **Use file locks** if concurrent writes are possible (e.g., multi-process data parallel).
- **One row per field per step**. If you have 5 scalar fields at step 100, that's 5 rows.

### Python helper pattern

```python
import csv
import datetime
from pathlib import Path
from threading import Lock

class ScalarWriter:
    def __init__(self, path: str):
        self.path = Path(path)
        self.lock = Lock()
        self._file = open(self.path, "a", newline="", buffering=1)
        self._writer = csv.writer(self._file)
        if self.path.stat().st_size == 0:
            self._writer.writerow(["timestamp", "step", "phase", "field", "value"])

    def write(self, step: int, phase: str, field: str, value: float):
        ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with self.lock:
            self._writer.writerow([ts, step, phase, field, value])
            self._file.flush()

    def write_dict(self, step: int, phase: str, metrics: dict):
        """Write multiple fields at once. Convenient for end-of-step logging."""
        ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with self.lock:
            for field, value in metrics.items():
                if value is not None:
                    self._writer.writerow([ts, step, phase, field, value])
            self._file.flush()

    def close(self):
        self._file.close()
```

Usage in training loop:
```python
scalars = ScalarWriter(f"{exp_dir}/records/scalars.csv")

for step, batch in enumerate(dataloader):
    loss = train_step(batch)
    scalars.write_dict(step, "train", {
        "loss": loss.item(),
        "learning_rate": scheduler.get_last_lr()[0],
        "grad_norm": grad_norm,
        "throughput": samples_per_sec,
    })
```

---

## events.jsonl — Per-Item Structured Logs

One JSON line per processed item/step, containing all `intermediate_fields` declared in the config. Written immediately, not buffered.

```jsonl
{"timestamp":"2026-04-03T15:01:00Z","step":0,"sample_id":"train-001","prediction":"Paris","ground_truth":"Paris","confidence":0.97,"latency_ms":12.3}
{"timestamp":"2026-04-03T15:01:00Z","step":1,"sample_id":"train-002","prediction":"Berlin","ground_truth":"London","confidence":0.52,"latency_ms":14.1}
```

### Rules

- Every line must be valid JSON. Use `json.dumps()`, never hand-format.
- Include `timestamp` and `step` in every line (same meaning as in scalars.csv).
- **Large values** (>1KB strings, arrays, tensors) should be truncated in events.jsonl and saved in full to `artifacts/`. Reference the artifact path in the event: `{"attention_map": "artifacts/attention_step_100.npy"}`.
- **Flush after every write**.

### Python pattern

```python
import json
import datetime
from pathlib import Path

class EventWriter:
    def __init__(self, path: str):
        self._file = open(path, "a", buffering=1)

    def write(self, event: dict):
        event["timestamp"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self._file.write(json.dumps(event, ensure_ascii=False) + "\n")
        self._file.flush()

    def close(self):
        self._file.close()
```

---

## artifacts/ — Large Outputs

For files too large or complex for CSV/JSONL: model checkpoints, images, plots, numpy arrays, confusion matrices, etc.

### Naming convention

Use descriptive names with step/epoch number:
```
artifacts/
├── checkpoint_step_10000.pt
├── confusion_matrix_eval.png
├── attention_heatmap_step_500.npy
└── best_model.pt
```

### Rules

- Save incrementally when possible (e.g., checkpoint every N steps, not just at the end).
- Reference artifact paths from events.jsonl when an event produced the artifact.
- For checkpoints, always save `best_model` based on the primary validation metric, in addition to periodic checkpoints.

---

## Recording Philosophy

**Record generously.** It's cheap to write an extra column; it's expensive to rerun a 10-hour job because you didn't log something you needed. If in doubt, record it.

But be practical:
- Tensors and large arrays should be summarized into scalar stats (mean, max, norm) for scalars.csv. Save raw data to artifacts/ only when specifically needed.
- Per-sample details go in events.jsonl, aggregate metrics go in scalars.csv.
- If a metric is computed anyway (like loss), always record it — the marginal cost is near zero.

---

## field_registry.json

After the user confirms the recording fields (SKILL.md Step 3), save the agreed-upon field list:

```json
{
  "scalar_fields": ["loss", "learning_rate", "grad_norm", "throughput"],
  "intermediate_fields": ["sample_id", "prediction", "ground_truth", "confidence"],
  "artifact_fields": ["best_checkpoint"],
  "confirmed_at": "2026-04-06T12:00:00Z",
  "proposed_by_ai": ["grad_norm", "throughput"],
  "accepted_by_user": ["grad_norm", "throughput"],
  "rejected_by_user": []
}
```

The `proposed_by_ai` / `accepted_by_user` / `rejected_by_user` fields document the negotiation — useful for understanding why certain fields are or aren't present.
