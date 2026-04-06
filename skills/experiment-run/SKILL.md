---
name: experiment-run
description: "Standards for writing experiment code and scripts — config-driven parameters, structured output directories, code snapshots, real-time CSV recording, and pre-flight confirmation. This skill is the mandatory reference for ANY code that produces outputs worth keeping. MUST read this skill when: (1) writing or modifying any script that runs training, evaluation, inference, or data processing; (2) designing output directory structure or recording config for an experiment; (3) creating Slurm launcher scripts or local run scripts; (4) the user asks to run/submit/launch an experiment; (5) writing code that logs metrics, saves checkpoints, or records results. Triggers on: sbatch, submit, train, eval, inference, experiment, run, launch, metrics, logging, checkpoint, scalars, CSV, record, output directory, exp dir, 跑实验, 提交任务, 起任务, 跑一下, 写训练脚本, 写脚本, 训练代码, 新实验, 实验代码, 输出目录, 记录metrics, exp目录, 创建训练脚本, scalars.csv, events.jsonl, run_manifest, field_registry, 实验记录, 跑训练, 跑一个实验, 写一个训练, 需要输出的脚本, 有输出的项目, 记录loss, 记录什么, 保存模型, 保存checkpoint. The code itself must satisfy these requirements — read BEFORE writing, not just before submitting."
---

# Experiment Run Skill (v2)

When a user asks you to run any code task (training, evaluation, data processing, inference, analysis, or anything else that produces outputs), follow this skill to ensure the run is config-driven, reproducible, and well-recorded.

The core idea: every run should be a self-contained capsule in `exp/` that a stranger could pick up months later and fully understand what was run, with what parameters, what code, and what happened.

**Last updated: 2026-04-06**

---

## Sub-skill Router

Route to the right reference file based on what you are about to do. Read ONLY the relevant file — do not load all of them.

| When you are about to... | Read this | Why |
|---|---|---|
| Build a config or decide what parameters go where | [references/config-schema.md](references/config-schema.md) | Config is the single source of truth for every run. Wrong structure = broken reproducibility. |
| Decide what metrics/fields to record, or write recording code | [references/recording-format.md](references/recording-format.md) | Exact CSV/JSONL formats, flush rules, field proposal logic. Getting the format wrong means broken plotting and analysis. |
| Set up the output directory or understand its layout | [references/output-directory.md](references/output-directory.md) | Directory naming, code snapshot, file layout. Wrong layout = scripts can't find outputs. |
| Generate a job script, choose backend, or submit a run | [references/job-generation.md](references/job-generation.md) | Slurm/local templates, backend detection, submission commands. Wrong template = job fails silently. |
| Show the pre-flight summary or confirm with the user | [references/preflight-checks.md](references/preflight-checks.md) | What to display, what to ask, how to catch missing fields before a 10-hour job starts. |
| Validate outputs after a run finishes | [references/postrun-validation.md](references/postrun-validation.md) | run_checks.json schema, validation checklist, failure reporting. |

---

## Mandatory Workflow (always follow this order)

1. **Determine backend** — Slurm or local? (see [job-generation.md](references/job-generation.md))
2. **Build config** — generate or load config.yaml (see [config-schema.md](references/config-schema.md))
3. **Negotiate recording fields** — this is critical, see below
4. **Pre-flight confirmation** — show summary, get user approval (see [preflight-checks.md](references/preflight-checks.md))
5. **Set up output directory** — create structure + snapshot (see [output-directory.md](references/output-directory.md))
6. **Generate and submit job** — write script, submit (see [job-generation.md](references/job-generation.md))
7. **Post-run validation** — check outputs (see [postrun-validation.md](references/postrun-validation.md))

---

## Recording Field Negotiation (Step 3 — do not skip)

Before writing any code, you must have a conversation with the user about what to record. This is the single highest-leverage moment in the workflow — it's cheap to add a field now and expensive to rerun a 10-hour job because you didn't log gradient norms.

### What you must do

1. **Ask the user** what they want to track. Be specific: "What metrics do you want to see in plots afterward? What per-item details do you want logged?"

2. **Propose additional fields** based on the task type. You understand the domain — use that knowledge. For each proposed field, explain in one sentence why it matters. The user can accept or reject each one.

   Example proposals by task type:

   **Training tasks** — always propose these if the user didn't mention them:
   - `loss` (total loss per step) — the primary signal; without it you're flying blind
   - `learning_rate` (current LR) — catches scheduler bugs and warmup issues
   - `grad_norm` (global gradient norm) — early warning for exploding/vanishing gradients
   - `throughput` (samples/sec or tokens/sec) — detects performance regressions
   - `gpu_memory_allocated` (peak GPU memory in MB) — catches memory leaks before OOM
   - `epoch` — tracks progress through the dataset
   - Per-component losses if the model has multiple loss terms (e.g., `loss_cls`, `loss_reg`)

   **Evaluation tasks** — always propose:
   - Primary metric (accuracy, F1, BLEU, etc. — depends on task)
   - Per-sample prediction + ground truth (in events.jsonl)
   - Confidence/probability scores if available
   - Latency per sample
   - Error categorization (what types of mistakes)

   **Data processing tasks** — always propose:
   - Items processed count
   - Items skipped/filtered count + reason
   - Processing time per item
   - Output size (bytes or tokens)
   - Any quality metric (if applicable)

   **Inference tasks** — always propose:
   - Latency per request (p50, p95, p99 if batched)
   - Throughput (requests/sec)
   - Token counts (input/output)
   - GPU utilization if available

3. **Classify each field** into one of three categories:
   - **scalar_fields** → goes into `scalars.csv`, for time-series plotting
   - **intermediate_fields** → goes into `events.jsonl`, per-item structured logs
   - **artifact_fields** → saved as files in `artifacts/`, for large outputs

4. **Confirm the final list** with the user before proceeding. Save to `field_registry.json`.

### Why this matters

Users routinely forget to log things they'll desperately want later. By proactively proposing fields, you save them from having to rerun experiments. The 30 seconds spent discussing fields now can save hours of re-computation.

---

## Universal Rules (apply to every run)

- **No hardcoding**: every parameter comes from config. If you catch yourself writing a magic number in a script, put it in the config instead.
- **Flush on write**: all record files flush after every write. If the job crashes, you keep everything written so far.
- **Immutable outputs**: once a run directory is complete, never modify existing files in it. You may append summary/check files.
- **Directory collision = abort**: if the output directory exists and is non-empty, stop and tell the user.
- **No silent drops**: if a record can't be written (permission error, disk full), fail loudly rather than silently skipping.
- **Config is the truth**: anyone should be able to read `config.yaml` and `run_manifest.json` in the output directory and fully understand what was run.
- **Record generously**: it's cheap to write an extra column; it's expensive to rerun a job because you didn't log something you needed.
