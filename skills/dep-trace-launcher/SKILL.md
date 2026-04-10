---
name: dep-trace-launcher
description: Interactive launcher that collects entry file / repo root / output directory / cap via AskUserQuestion, then hands off to the `recursive-dep-trace-parallel` skill. Guesses plausible defaults by scanning the current working directory for entry-point-shaped files and infers the repo root from the chosen entry. Use whenever the user says "帮我启动一个依赖追踪", "准备跑依赖分析", "我要追踪某个脚本的依赖", "dep-trace launcher", "/trace-deps" or similar — anything that means "I want to start a dep trace but don't want to hand-type paths". Do NOT use this launcher when the user has already given you all three paths explicitly; in that case call recursive-dep-trace-parallel directly.
---

# Dependency Trace Launcher

## Why this exists

`recursive-dep-trace-parallel` needs three absolute paths (entry, repo root, output dir) plus a cap. Typing these into a fresh prompt is tedious and error-prone — missing a trailing slash, mixing up snapshot vs upstream, putting artifacts inside a read-only source tree. This launcher collects those four inputs in one confirmation round, guessing sensible defaults so the user usually just clicks "accept".

The launcher does not do the trace itself. Its whole job is: guess → ask → confirm → hand off.

## Workflow

### Step 1 — Guess plausible entry points

Scan the current working directory for files that look like entry points:

- Top-level `*.py` files with these name patterns (highest priority first):
  - `main.py`, `run.py`, `entry.py`, `app.py`
  - `train*.py`, `eval*.py`, `test_*.py` (lower priority)
  - `generate_*.py`, `script*.py`
  - `minimal_*.py`
- Top-level `*.ipynb` files (only if no `.py` entry candidate found)

Use Glob. Collect up to 5 candidates, sorted by name-priority then mtime. If cwd has no candidates, walk one level down into obvious source directories (`src/`, `scripts/`) but do not descend further — the user will pick "other" if needed.

If the user mentioned a specific filename in their invocation (e.g. "追踪 minimal_generate_image_v3.py"), put that one first in the candidate list regardless of pattern match.

### Step 2 — Infer repo root for each candidate

For each candidate entry, the guessed repo root is the directory containing a `.git` / `requirements.txt` / `pyproject.toml` / `setup.py` at or above the entry file. Walk up from the entry's parent directory. If none of those markers exist, default to the entry's parent directory.

### Step 3 — Propose an output directory

The default output directory is:

```
<repo_root_parent_or_workspace>/artifacts/task_<slug>_parallel/
```

Where `<slug>` is the entry's basename without extension, lowercased, with non-alphanumeric characters replaced by underscores.

Prefer placing artifacts in a parent project directory if the repo root is itself under an `external/` or `third_party/` subtree (a strong signal the repo is a read-only snapshot you don't want to pollute). Specifically:

- If repo root path contains `/external/`, `/third_party/`, `/vendor/`: walk up until leaving that subtree, then propose `<that_ancestor>/artifacts/task_<slug>_parallel/`
- Otherwise: propose `<repo_root>/artifacts/task_<slug>_parallel/`

### Step 4 — Ask the user (single AskUserQuestion turn)

Present the four decisions together in a single `AskUserQuestion` call with four questions:

1. **entry** — list of candidate entries (from Step 1) + "other" ("让我手动给路径")
2. **repo_root** — the inferred repo root for whichever entry the user picked, or "other". Since this depends on entry choice, present the inferred root of the first candidate and note in the header that picking a different entry may change this.
3. **output_dir** — the proposed output dir from Step 3, plus "other"
4. **cap** — `20` (default), `30`, `40`, or "other"

Keep option labels short (< 40 chars). Full paths go in `description`.

If the user picks "other" for any question, follow up with a free-form text question for just that field.

### Step 5 — Confirm and hand off

After receiving answers:

1. Print the four finalized values back to the user as a short block so they can see exactly what will run:
   ```
   入口:     <path>
   仓库根:   <path>
   输出目录: <path>
   Cap:      <N>
   ```
2. Ask one final confirmation with AskUserQuestion: "开始追踪吗?" with options "开始" / "再改一次" / "取消".
3. On "开始": create the output directory with Bash (`mkdir -p`) then immediately invoke the `recursive-dep-trace-parallel` skill by reading its SKILL.md and playing the root coordinator role yourself with the confirmed parameters. **The launcher does not delegate to a subagent — it becomes the root agent for the trace.** This is important because subagents can't call Task, and the trace needs parallel worker dispatch.
4. On "再改一次": re-run Step 4 with the same defaults pre-filled (user can just tweak one field).
5. On "取消": print "已取消" and stop.

## What the launcher must NOT do

- **Do not run the trace with defaults without confirmation.** The whole point is the user sees and approves paths before any trace artifacts are created. A wrong output dir could litter a production repo; a wrong repo root could silently include the wrong source tree.
- **Do not try to auto-detect the "right" entry from project structure heuristics beyond what Step 1 says.** Users know which script they care about; the launcher should give them 3-5 good guesses, not pretend to be smart.
- **Do not write any files before the final "开始" confirmation.** No `_state.md`, no `closure.zh.md`, no output dir creation until the user has explicitly greenlit.
- **Do not chain multiple traces in one invocation.** One launcher call = one trace. If the user wants to trace two entries, they invoke the launcher twice.

## Example session (illustrative)

```
User: /trace-deps

Launcher: [scans cwd, finds main.py, train.py, generate_nonStat_newLineRemoval_v2.py]
Launcher: [AskUserQuestion with 4 questions]
  Q1 entry: [main.py / train.py / generate_nonStat.../ other]
  Q2 repo_root: [/home/user/proj (default) / other]
  Q3 output_dir: [/home/user/proj/artifacts/task_main_parallel/ (default) / other]
  Q4 cap: [20 / 30 / 40 / other]

User: [picks train.py, keeps repo_root default, picks other for output_dir]

Launcher: [follow-up AskUserQuestion for output_dir text input]
User: /tmp/my_trace/

Launcher:
入口:     /home/user/proj/train.py
仓库根:   /home/user/proj/
输出目录: /tmp/my_trace/
Cap:      20

Launcher: [AskUserQuestion: 开始?]
User: 开始

Launcher: [mkdir -p /tmp/my_trace/worker_reports]
Launcher: [reads recursive-dep-trace-parallel SKILL.md]
Launcher: [begins Step 0 of that skill with the confirmed params]
```

## Hand-off contract

When the launcher transitions to the parallel trace skill, it is still the same Claude session. No Task delegation. The launcher just stops talking about collecting inputs and starts behaving according to `recursive-dep-trace-parallel`'s SKILL.md, using the four confirmed values as its input parameters.
