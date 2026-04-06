# Config Schema

Every run needs a config file (YAML or JSON). If the user doesn't provide one, generate a template from their request and ask them to confirm before proceeding.

The config has two parts: **fixed structure** (same for all tasks) and **task-specific params** (user defines freely).

---

## Fixed Structure

These fields must exist in every config. They define the run identity, execution backend, snapshot behavior, and output location.

```yaml
run:
  name: ""              # Names the output directory. Keep it short and descriptive.
                        # Example: "bert-finetune-lr-sweep", "eval-gpt4-math", "process-wiki-dump"
  description: ""       # One line: what this run does and why.
                        # Example: "Fine-tune BERT on SQuAD v2 with cosine LR schedule"
  task_type: ""          # train / eval / process / infer / analyze / other
                        # This determines which recording fields to propose (see SKILL.md Step 3).
  entrypoint: ""         # The command to execute.
                        # Examples: "python train.py", "python -m my_module", "bash run.sh"

backend:
  type: ""               # slurm / local / pbs / lsf (determined in job-generation.md Step 1)
  partition: ""          # Scheduler partition/queue (ignored if local)
  time_limit: "02:00:00" # Wall time limit. Be generous — a job killed by timeout loses all unsaved work.
  cpus: 4
  gpus: 0               # 0 = no GPU needed. For training, typically 1-8.
  memory: "16G"          # Per-node memory. Check actual usage after first run and adjust.

snapshot:
  enabled: true          # Whether to copy project code into the output directory.
                        # Almost always true. Only disable for huge repos where rsync is slow.
  exclude: [".git", "__pycache__", ".cache", "exp", ".venv", "node_modules"]
                        # Directories to skip during snapshot. Add large data dirs here.

output:
  root: "exp"            # Output root relative to project directory.
                        # All run directories are created under this path.
```

---

## Task-Specific Params

The user puts whatever they need here. The skill makes zero assumptions about these fields — they're entirely domain-specific.

```yaml
params:
  # User puts whatever they need here. Examples:
  #   learning_rate: 3e-4
  #   batch_size: 32
  #   model_path: "/data/checkpoints/step-1000"
  #   input_file: "data/test.jsonl"
  #   num_epochs: 10
  #   warmup_steps: 500
  # The skill makes zero assumptions about these fields.
```

The reason every parameter lives in the config (not hardcoded in scripts) is reproducibility: someone reading `config.yaml` in the output directory should know exactly what was run without reading the code.

---

## Recording Section

This section declares what the run will record. It is populated during the Recording Field Negotiation step (SKILL.md Step 3) — never fill this in silently.

```yaml
recording:
  scalar_fields: []       # Numeric values to track in scalars.csv (for plotting).
                          # Examples: loss, learning_rate, grad_norm, accuracy, throughput
                          # These become rows in the long-format CSV.

  intermediate_fields: [] # Per-item fields to log in events.jsonl.
                          # Examples: sample_id, prediction, ground_truth, confidence, latency_ms
                          # One JSON line per processed item/step.

  artifact_fields: []     # Large outputs saved as files in artifacts/.
                          # Examples: best_checkpoint, confusion_matrix_plot, attention_heatmap
                          # For anything >1KB that doesn't fit in a CSV cell.

  interval_rows: 50       # Write an aggregate snapshot to scalars.csv every N items.
  interval_seconds: 60    # Or every N seconds, whichever comes first.
                          # These control how often scalars.csv gets a new row.
                          # Smaller intervals = more granular plots but larger files.
```

---

## Config Loading in Code

The entrypoint script should load the config at startup. Recommended pattern:

```python
import yaml
from pathlib import Path

config = yaml.safe_load(Path("config.yaml").read_text())

# Access fixed fields
run_name = config["run"]["name"]
task_type = config["run"]["task_type"]

# Access user params
lr = config["params"]["learning_rate"]
batch_size = config["params"]["batch_size"]

# Access recording config
scalar_fields = config["recording"]["scalar_fields"]
```

Every parameter the script uses must come from the config. If you find a value that's hardcoded in the script but could vary between runs, move it to `params:`.
