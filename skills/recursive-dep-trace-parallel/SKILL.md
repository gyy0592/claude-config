---
name: recursive-dep-trace-parallel
description: Recursively read every line of every file reachable from an entry script. Main Claude is the root coordinator. The root holds one queue of files-to-read. It dispatches workers in parallel batches (multiple Task calls in one message) to read those files. Every worker reads every single line of its assigned file and reports every external reference it sees — imports, `np.load` / `pickle.load` / `open(...)` / `h5py.File` / any path literal — as new items for the queue. The queue is drained to empty before anything is called done. Use whenever the user asks for recursive dependency tracing, "把每一行代码都读一遍", "确保每个文件都被读完", "并行追踪依赖", parallel dep tracing, or any task that requires exhaustive code+data closure analysis from a single entry point.
---

# Recursive Dependency Trace — Parallel

## The only rule

**Read every line of every file that can be reached from the entry. When a file mentions any other file by name, import, or path literal, push that other file onto the queue. Stop only when the queue is empty and every file in `seen` has a worker report marked DONE.**

That's it. No "producer" category. No "asset vs code" split. No "inference scope" shortcuts. No "this is just a data file, skip it". Every mentioned file gets pushed. Every queued file gets read line-by-line. Queue drains to zero. Done.

## What counts as "mentioning another file"

A worker reading a file must flag all of these as new queue items:

1. **`import X` / `from X import Y`** — push the Python file that defines the module
2. **`np.load('X')` / `np.loadtxt('X')` / `np.savez('X')`** — push X
3. **`pickle.load(open('X', ...))` / `pickle.dump(..., open('X', ...))`** — push X
4. **`torch.load('X')` / `torch.save(..., 'X')`** — push X
5. **`yaml.safe_load(open('X'))`** — push X
6. **`open('X', 'r'...)`** for reading any file — push X
7. **`open('X', 'w'...)` / `open('X', 'a'...)`** — push X (even if it's an output, the output path is part of the pipeline closure)
8. **`h5py.File('X', ...)`** — push X
9. **`pd.read_csv('X')` / `pd.read_parquet('X')`** — push X
10. **`TimeSeries.read('X', ...)`** — push X
11. **`Image.open('X')` / `cv2.imread('X')`** — push X
12. **`glob.glob('<pattern>')`** — push the pattern (root will expand it and push each match)
13. **Any string literal that looks like a filesystem path** (contains `/` and a plausible extension like `.npz/.pkl/.pth/.yaml/.yml/.json/.csv/.hdf5/.npy/.txt/.h5`) used as an argument to any function — push the literal, root decides what to do
14. **Subprocess / shell commands that reference another script** (e.g. `subprocess.run(['python', 'other_script.py'])`) — push that script
15. **`nbformat` / notebook cell execution of another notebook** — push the notebook

If a worker is unsure whether something counts, it pushes it. The root resolves.

## What counts as "reading every line"

Worker must cover line 1 to EOF of the target file. If the file is a Python source file, every line is read, including lines inside `if __name__ == '__main__'`, inside every function body, inside every conditional branch — not just the top-level imports. A function body's `np.load('foo.npz')` is just as important as a top-level one. Dead-looking code is read.

If the file is a notebook (`.ipynb`), every cell is read, both code and markdown. Output cells are ignored.

If the file is a data file that the root decided to inspect (`.npz` / `.pkl` / `.json` / `.yaml` / `.csv`), the worker:
- For `.npz`: list keys, for each key print dtype/shape, and if dtype is string/object, sample all values and look for path-shaped strings. Every path-shaped string gets pushed to the queue. Every one, not a sample.
- For `.pkl`: `pickle.load` + walk the structure recursively looking for strings that look like paths. Push each path.
- For `.json` / `.yaml`: parse and walk for path-shaped strings.
- For `.csv`: read header + all rows, flag any column whose values look like paths, push each path.

If the worker can't open the data file for any reason (corrupted, unknown format), it reports the failure as a HOLE and moves on.

## Queue item types

Only two types live in the queue:

1. **File to read** — an absolute path to a .py / .ipynb / data file. Gets dispatched to a worker.
2. **Reference to resolve** — a string that mentions another file but the root hasn't figured out the absolute path yet (e.g. `config/manifest.npz` which needs to be joined with some base dir, or a glob pattern that needs expansion, or a module name like `utils.foo` that needs to be mapped to a filesystem path). The root resolves these itself with Glob/Grep, then converts them into type-1 items.

The root maintains `seen (paths)` so the same file is never queued twice.

## Leaves (where recursion stops)

1. **Third-party package** — `torch`, `numpy`, `gwpy`, `pycbc`, etc. Listed in the third-party library summary at the end, not traced.
2. **External URL / public data source** — `https://...`, GWOSC API endpoints, etc. Listed as external dependencies, not traced.
3. **File that does not exist anywhere searchable** — after three distinct search strategies fail to find it, the file becomes a HOLE. Recorded in the HOLES section with the three commands that were tried. Trace continues on other branches.

Everything else — every file that exists and can be opened — is read.

## Files and state

```
artifacts/task_<name>/
├── _state.md           # live state: queue, seen, holes, dispatched_total
├── closure.zh.md       # grows incrementally: entry summary, per-file table, third-party list, HOLES, external leaves
└── worker_reports/
    ├── 001_entry.md    # root's own read of the entry
    ├── 002_utils_a.md
    ├── ...
```

`_state.md` is rewritten after every single batch dispatch and every single merge. If the run crashes, restart reads `_state.md` + checks which worker reports end in `## DONE`, and resumes the queue from there.

`closure.zh.md` is grown with `Edit` — append rows as workers return, never rewrite from scratch mid-run.

## `_state.md` format

```markdown
# Trace state
- entry: <abs path>
- task_dir: <abs path>
- dispatched_total: N  # cumulative count, informational only
- max_parallel: 20  # max workers dispatched in ONE batch (per assistant message). No cumulative cap.
- last_updated: YYYY-MM-DD HH:MM:SS
- status: in_progress | serial_fallback | done

## queue (files to read, pending dispatch)
- /abs/path/utils/a.py (pushed by 001 main.py:L8)
- /abs/path/config/BarrysMockTrain_paths.npz (pushed by 015 train.py:L143, type=data-inspect)
- ...

## references to resolve (not yet mapped to absolute paths)
- "config/manifest.npz" (pushed by 001 main.py:L19, base_dir=unknown)
- "utils.foo" (module name, pushed by 002 a.py:L3)
- ...

## seen (absolute paths already queued or done)
- /abs/path/main.py (worker 001 DONE)
- /abs/path/utils/a.py (worker 002 in-flight)
- ...

## holes (three searches failed, not found anywhere)
- config/fitted_psd.npz (pushed by 001, searches: grep-full-path, grep-basename, grep-savez → 0 matches each)
- ...

## in_flight (current batch)
- 002 /abs/path/utils/a.py
- 003 /abs/path/utils/b.py
- ...
```

## Worker prompt (template)

Each worker receives:

```
You are a stateless file-reader worker. Read exactly one file line by line, report every external reference, exit.

Target file: {ABSOLUTE PATH}
Worker id: {NNN}
Output md: {ABS PATH TO worker_reports/NNN_slug.md}
Type: source | notebook | data-inspect

## Rules
- Do NOT execute the target code.
- Do NOT spawn further subagents (you cannot anyway).
- Do NOT stop at imports — read every line, including inside functions, classes, conditionals, __main__ blocks.
- For .py / .ipynb files: use Read tool, if file > 1000 lines read in chunks until EOF.
- For data-inspect type (.npz / .pkl / .json / .yaml / .csv):
    * .npz: use Bash to run `python3 -c "import numpy as np; d=np.load('FILE', allow_pickle=True); print(list(d.keys())); ..."` to list keys, dtypes, shapes, and for string arrays dump every value to find path-shaped strings
    * .pkl: `python3 -c "import pickle; d=pickle.load(open('FILE','rb')); ..."` walk the structure looking for strings
    * .json / .yaml: use Read tool, parse, walk for path-shaped strings
    * .csv: use Read tool on header and sampling rows, or python csv module for full column scan
  Data-file inspection IS allowed to run small python snippets because the target itself is not being executed — we're just opening a data artifact the target would read.

## What to report
Every external reference seen in the file, in these categories:
- imports: local python modules
- io_reads: np.load, pickle.load, torch.load, yaml.safe_load, open(...,'r'), h5py.File, TimeSeries.read, pd.read_csv, Image.open, etc.
- io_writes: np.savez, pickle.dump, torch.save, open(...,'w'), etc.
- path_literals: any string that looks like a filesystem path (contains '/' and a plausible extension), regardless of what function it's passed to
- subprocess_calls: any subprocess.run / os.system that invokes another script
- third_party: pip-installable packages used (numpy, torch, gwpy, ...)
- suspected_holes: imports of modules whose .py file you verified via Glob does not exist

## Output
1. Write `worker_reports/NNN_slug.md` with sections: Worker header, 读取范围 (line range covered), 中文摘要 (2-4 lines), imports, io_reads, io_writes, path_literals, subprocess_calls, third_party, suspected_holes, ## DONE (last line).
2. Final chat message, exactly one line:
DONE id=NNN path=<output_md> refs=<comma-separated list of every new reference: "import:utils.foo", "read:config/x.npz", "write:out/y.pkl", "path:data/z.hdf5", "subproc:other.py"> holes=<comma-separated suspected_holes>
```

Worker returns a single line, root parses and pushes every new reference into the queue (after dedup against seen).

## Root coordinator loop

### Step 0 — Startup
- Fresh: create `artifacts/task_<name>/`, seed empty `_state.md`, seed `closure.zh.md` with empty section headers, add entry to queue.
- Resume: read `_state.md`, list `worker_reports/`, any in-flight worker without `## DONE` in its md goes back into the queue.

### Step 1 — Read entry directly
Root reads the entry file itself with Read tool (so we don't waste one dispatch on the file we already know about). Writes `worker_reports/001_entry.md` in worker format. Extracts every reference. Pushes to queue. Rewrites `_state.md`. Appends §1 entry summary row to `closure.zh.md`.

### Step 2 — Main loop

While queue is non-empty:

1. Pop up to `max_parallel` (default 20) items from queue (batch). `max_parallel` is the per-batch concurrency limit, NOT a cumulative cap — you can run as many batches as the queue requires.
2. For each item, if it's a reference-to-resolve (relative path, module name, glob pattern), resolve to an absolute path using Glob/Grep. If resolution fails after three distinct search strategies, mark as HOLE in `_state.md` and `closure.zh.md §HOLES`, and do not dispatch.
3. For each resolved absolute path not in `seen`, add to `seen`, assign worker id, prepare dispatch.
4. Rewrite `_state.md` with new `in_flight` list.
5. In ONE assistant message, emit N Task tool calls — one per file in the batch. Each Task prompt is the worker prompt template filled in.
6. Wait for all N to return.
7. For each returned one-line `DONE id=... refs=... holes=...`:
    - Parse refs. For each reference: check dedup against seen; if new, push into queue (or references-to-resolve if not yet absolute).
    - Parse holes. Add to HOLES list.
    - Append the worker's file row to `closure.zh.md §3 per-file table` using Edit.
    - Append the worker's third-party entries to `closure.zh.md §7` deduped.
8. Rewrite `_state.md`.
9. Loop.

### Step 3 — Serial fallback (optional)

There is NO cumulative cap. Loop batches until the queue is empty. Only fall back to root-serial reads if parallel dispatch is failing (tool errors, repeated timeouts). In that case set `status: serial_fallback` in `_state.md` and continue reading remaining files with Read / Bash until the queue drains.

### Step 4 — Finalize preflight

Before writing `status: done`, verify:

1. Queue is empty.
2. References-to-resolve is empty (every reference became either an absolute path that got dispatched, or a HOLE).
3. Every path in `seen` has a `worker_reports/NNN_*.md` file whose last non-empty line is `## DONE`.
4. For every `io_read` / `io_write` / `path_literal` recorded across all worker_reports, the target is either (a) in `seen` with DONE, (b) a HOLE, or (c) a third-party / external URL.

If any of 1-4 fails, do not finalize. Go back to Step 2.

### Step 5 — Write final sections

Fill `closure.zh.md`:
- §2 import/reference tree — built from parent pointers recorded during dispatch
- §5 HOLES — with each hole's three search commands and what pushed it
- §6 external leaves — GWOSC URLs, third-party APIs, anything not in the repo
- §7 third-party libraries

Report to user: one-line verdict + files-traced / holes / externals counts + path to closure doc.

## Anti-patterns

- **Stopping when the "main flow" looks done.** If the entry has `if __name__ == '__main__'` with 3 branches, all 3 branches are read and all references in all 3 branches are pushed. The user may only care about one branch, but that's their decision to make after seeing the full closure.
- **Skipping a file because it's "just data".** A `.npz` that's bundled in the repo with path-strings inside is a manifest. Open it. Push every path. Failing to do this is how `BarrysMockTrain_paths.npz` slipped through as "resolved" when it actually pointed at 4600 files nobody has.
- **Treating "has a producer" as "resolved".** Finding `np.savez('foo.npz')` in script X means push script X onto the queue, not mark foo.npz as resolved. foo.npz is resolved only after X is fully traced and X's own dependencies are all either traced or HOLE.
- **Batching doc updates to the end.** Every worker return → immediately update `_state.md` + append to `closure.zh.md §3`. Any delay is how progress gets lost to context exhaustion.
- **Declaring DONE with nonzero queue or nonzero references-to-resolve.** The finalize preflight exists to catch this. If the preflight fails, go back to Step 2 and keep working.
- **Skipping the data-inspect step for bundled `.npz` / `.pkl`.** Every data artifact that is committed to the repo gets opened and walked. No exceptions.
- **Filtering references by "is this inference-relevant?" at trace time.** That's a user-facing post-trace filter, not a skill-level shortcut. Trace everything, let the user filter.

## Escalation to user

Escalate only when:
1. Finalize preflight keeps failing after second-pass on HOLES.
2. The entry has multiple disconnected `if __name__ == '__main__'` subcommands that would take very different traces, and clarifying which is in scope would cut the work in half. (Even then, default behavior is trace everything.)
3. The closure contains structural impossibilities (import from module that provably never existed in any reachable version of the repo).

Never escalate to avoid work. Trace first, surface questions after.
