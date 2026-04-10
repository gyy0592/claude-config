---
name: recursive-dep-trace
description: Recursive first-principles static dependency tracing for a single code entry point, producing a real-time stream-of-consciousness trace markdown that embodies the AI's reading process as a call-stack of TODOs. Given one entry script (e.g. `train.py`, `minimal_generate_image_v3.py`, `main.py`), the AI reads the code line-by-line, stops at every external dependency, pushes it onto a TODO stack with "paused at line N of parent" bookkeeping, recurses, pops, and resumes — updating the same markdown file after every tiny reading step so the final document is a complete proof that a fresh agent can run the entry from an empty machine. Use whenever the user says things like "递归分析依赖", "第一性原理级别的依赖闭包", "为了从头跑起 X 需要什么", "trace dependencies for X", "required_dependencies 文档", "精确到每一行的依赖追踪", or pins a task to recursive static dependency analysis. Also use proactively when preparing a repo for open-source release, minimal-reproducible-example extraction, or auditing whether a training/inference pipeline is truly self-contained and has no silent gaps. Do NOT use for runtime debugging or test execution — this skill is pure static reading.
---

# Recursive Dependency Trace

## Why this skill exists

When preparing a codebase for release, extracting a minimal reproducible example, or handing a repo to a collaborator, the critical question is: **if someone starts from an empty machine with nothing but this repo, can they run this entry script to completion using only what the repo enumerates + clearly-listed external assets?**

Answering that well means tracing every import and every disk I/O operation, recursively, until every branch terminates at either (a) a resolved internal definition, (b) a documented external asset, or (c) a provable dead end. Anything less is a wishful thinking, and wishful thinking is exactly what ships broken "minimal examples" to collaborators.

The deliverable is a single markdown file that grows in real time as the AI reads. The file itself is the AI's thinking process — not a retrospective summary, not a polished report, but a live trace: "now I'm looking at lines 1-3, I see `import A, B, C`; A is a package so I check requirements; B is a local file `utils/foo.py`, push TODO; C is a local file `utils/bar.py`, push TODO; now I read TODO-top which is B; open `utils/foo.py` line 1..." and so on. When the AI's context window ends, the file must contain enough to let a fresh agent pick up exactly where the previous one left off.

This matters because these traces are long. Hundreds of file reads, thousands of lines. The only way to not lose progress is to treat the markdown as the working memory — update it after every tiny reading step, not at the end.

## The one absolute rule

**Read every line of every file that the entry can reach. When a file mentions any other file — by import, by `np.load` / `pickle.load` / `torch.load` / `yaml.safe_load` / `open(...)` / `h5py.File` / `pd.read_csv` / `TimeSeries.read` / any path-shaped string literal / any subprocess call to another script — push that other file onto the TODO stack. Stop only when the TODO stack is empty and every file in the Done list has been read line 1 to EOF.**

That's it. There is no "producer" category and no "asset" category. Every file that gets mentioned is just another file to read. "Finding a producer" is not a terminal state — it just means "push that producer onto the stack so it gets read like any other file". The producer's own dependencies (its imports, its `np.load` calls, its path literals) then become new TODOs, and so on, until the stack drains.

A bundled data file in the repo (`.npz`, `.pkl`, `.json`, `.yaml`, `.csv`) is NOT a leaf. It is opened and inspected. If its contents contain path-shaped strings, every one of those paths is pushed onto the TODO stack as a new reference to resolve. This is how `BarrysMockTrain_paths.npz` would have been caught: it is an npz containing 4600 absolute path strings pointing to files that don't exist in the repo, and a proper trace pushes every one of those 4600 paths and discovers none of them can be found.

Recursion stops only at three kinds of leaves:
1. **Another file already in Done** — means it's already been fully read to EOF.
2. **A third-party pip package** (torch, numpy, gwpy, ...). Listed at the bottom, not traced.
3. **An external public resource** (GWOSC URL, HTTPS endpoint). Listed as external prerequisite, not traced.

Anything that is not one of those three and is also not in Done is a pending TODO. The trace is not finished until the TODO stack has zero non-BLOCKED items.

## Core rules (non-negotiable)

1. **Pure static reading by default.** Use Read, Grep, Glob, AST parsing. Do not execute the target code. The whole value proposition is that this works on repos whose environment isn't set up. Opening bundled data files (`.npz` / `.pkl` / `.json` / `.yaml` / `.csv`) with small Python inspection snippets IS allowed — that is not "executing the target", it is reading a data artifact. Executing the target's `.py` files is forbidden.

2. **Read every line of every file to EOF.** When a file is popped off the TODO stack (or pushed as the entry), the trace reads it from line 1 all the way to the last line. Not just the import block. Not just top-level code. Not just the `if __name__ == '__main__'` branch that looks "main". Every function body, every class method, every conditional branch, every `__main__` block. An `np.load('X.npz')` on line 1800 of a 2000-line file is just as important as one on line 5, and missing it means the trace has a hole.

3. **Push a TODO at every external reference encountered during the line-by-line read.** The list of things that count as an external reference:
   - `import X` / `from X import Y` where `X` is a local module → push the .py file that defines the module
   - `np.load(...)`, `np.loadtxt(...)`, `np.savez(...)` → push the path argument
   - `pickle.load(...)` / `pickle.dump(...)` → push the path argument
   - `torch.load(...)` / `torch.save(...)` → push the path argument
   - `yaml.safe_load(open(...))` → push the path argument
   - `open('X', 'r')` / `open('X', 'w')` / `open('X', 'a')` → push X (writes count too — output paths are part of the pipeline closure)
   - `h5py.File('X', ...)` → push X
   - `pd.read_csv('X')` / `pd.read_parquet('X')` → push X
   - `TimeSeries.read('X', ...)` → push X
   - `Image.open('X')` / `cv2.imread('X')` → push X
   - `glob.glob('<pattern>')` → push the pattern (you resolve it with Glob later)
   - **Any string literal that looks like a filesystem path** (contains `/` and a plausible extension `.npz/.pkl/.pth/.yaml/.yml/.json/.csv/.hdf5/.npy/.txt/.h5`), regardless of what function it's passed to → push the literal
   - `subprocess.run([...])` / `os.system(...)` that invokes another script → push that script
   - `nbformat` / Jupyter cell execution of another notebook → push the notebook

   Pushing a TODO does NOT stop reading. Keep reading line-by-line until EOF. Multiple TODOs can accumulate from a single file read. The reading of a file is complete only at EOF, not at the first TODO.

3a. **Data-file inspection rule.** When a TODO popped off the stack is a bundled data file (`.npz` / `.pkl` / `.json` / `.yaml` / `.csv` that exists in the repo), the trace opens it:
   - `.npz`: run `python3 -c "import numpy as np; d=np.load('FILE', allow_pickle=True); print(list(d.keys())); [print(k, d[k].dtype, d[k].shape) for k in d.keys()]; [print(k, d[k].tolist()[:5]) for k in d.keys() if d[k].dtype.kind in ('U','O')]"` with Bash. List every key, print dtype/shape. For any key whose dtype is string or object, dump ALL values (not a sample) and look for path-shaped strings. Every path found is pushed to the TODO stack as a new reference.
   - `.pkl`: `python3 -c "import pickle; d=pickle.load(open('FILE','rb')); print(type(d)); print(d)"` then walk the structure looking for path-shaped strings. Push every one.
   - `.json` / `.yaml`: Read + parse + walk for path-shaped strings. Push every one.
   - `.csv`: Read header + all rows (or column scan). Push any column whose values look like paths.
   
   Failing to open and inspect a bundled data file is how `BarrysMockTrain_paths.npz` slipped through in a previous trace as "resolved — has a producer" when it was actually a manifest pointing at 4600 private files. Do not make that mistake again.

3. **TODO stack with resume bookkeeping.** TODOs live in a stack at the top of the trace markdown. Each frame records: (a) what the TODO is (file to read, asset to resolve, function to locate), (b) which parent TODO spawned it and at which line (e.g. "parent: `train.py:L27 from utils.foo import bar`"), (c) the current progress on this TODO (e.g. "reading `utils/foo.py`, paused at L47"). When you push a new TODO, mark the current TODO as "paused at L<current_line>". When you pop a TODO (finished), resume the parent at its saved line and immediately update the markdown to reflect the new stack state.

4. **BLOCKED handling: skip, don't block.** If a TODO cannot be resolved after 3 genuinely exhaustive search attempts (see Rule 5), mark it `BLOCKED` with the list of searches tried and *keep going* — work the next TODO on the stack. Do not halt the whole trace on a single missing piece. Only after the full TODO stack is drained (everything else resolved) do you come back to the `BLOCKED` items and try one more round with fresh context. Items still unresolvable at that point get reported to the user as concrete questions.

5. **"3 attempts exhaustive" means actually exhaustive.** Before marking `BLOCKED`, you must have tried at least three substantively different search strategies. Examples of distinct strategies:
   - `grep -r "exact_name" .`
   - `grep -rn "def exact_name\|class exact_name"` across all relevant dirs including sibling/snapshot/upstream repos
   - `grep -rn "partial_name"` / `grep -rn "similar_stem"` for renamed or abbreviated versions
   - `find . -name "*exact*"` for filename-based search
   - Reading `__init__.py` files in candidate packages for re-exports
   - Checking requirements.txt / setup.py / pyproject.toml for package aliases
   
   Log every attempted command verbatim in the BLOCKED entry. Three copies of the same grep with different quoting does not count as three attempts.

6. **The markdown is working memory, not a report.** Update it after every single reading step. Every file opened, every TODO pushed, every TODO popped, every line range read, every grep run — these all go into the trace log in order. The stream-of-consciousness style is mandatory. If context runs out mid-trace, a fresh agent should be able to read the markdown and resume at exactly the right file:line with the exact TODO stack restored.

7. **Required-files section is line-precise.** The bottom of the markdown has a `## Required files` section that lists every source file, data asset, and config the entry point needs, with **exact line ranges** when a file is only partially needed. Example: `utils/myfuncs/obtain_strain.py L1-L87, L325-L381 (needed for get_strain_data + split_strain_into_segments)`. If the whole file is needed, write `L1-end`. This precision is what makes the trace useful for minimal-example extraction.

8. **Finalize preflight.** Before writing the final trace summary or telling the user "done", verify all of these:
   - TODO stack contains only `[blocked]` items, no `[active]` or `[paused]` left.
   - Every file listed in "Done" has been read line 1 to EOF (the log shows line ranges that cover the whole file).
   - Every reference recorded in the log — every import, every `np.load`, every `pickle.load`, every path literal — is either (a) itself listed in Done, (b) listed in the third-party library section, (c) listed as an external URL / public resource, or (d) listed as BLOCKED with three search commands recorded.
   - Every bundled data file encountered was data-inspected per Rule 3a, and every path-shaped string found inside it has been traced to one of the same four states above.
   
   If any check fails, the trace is not done. Pop the next uncovered item back into `[active]` and keep reading.

## Trace markdown structure

The trace file lives at `artifacts/task_<name>/<entry_name>_trace.zh.md` and has exactly this layout. Create it on step 1 and update it in place:

```markdown
# 递归依赖追踪: <entry_script>

> 本文档由 recursive-dep-trace skill 实时维护。
> 任何时刻该文档都反映当前最新的 TODO 栈和阅读进度。
> 若被中断,下一个 agent 可从 "## 当前栈顶" 直接恢复。

## TODO 栈(栈顶在最上,先处理栈顶)

1. **[active]** <当前正在处理的 TODO>
   - 做什么: 读 `utils/foo.py` 第 47 行开始
   - 父: `train.py:L27` 处 `from utils.foo import bar`
   - 进度: 已读 L1-L46,暂停在 L47
2. **[paused]** <被栈顶暂停的上一个 TODO>
   - 做什么: 读 `train.py`
   - 父: 入口
   - 进度: 已读 L1-L27,暂停在 L27
3. **[blocked]** <临时跳过的 TODO,最后再处理>
   - 做什么: 定位 `save_output.py` 模块
   - 父: `train.py:L41 from utils.myfuncs.save_output import setup_csv, append_to_csv`
   - 尝试:
     1. `grep -rn "def setup_csv" .` → 0 命中
     2. `find . -name "save_output*"` → 0 命中
     3. `grep -rn "setup_csv" external/OoD_nonStationary_snapshot` → 0 命中
   - 状态: BLOCKED,待全部 TODO 清空后重试

## 阅读轨迹(流式,追加,不修改历史)

### 2026-04-09 15:32 — 开始追踪
入口: `train.py`
当前栈: [ train.py (entry) ]

### 2026-04-09 15:33 — 读 train.py L1-L3
```python
from __future__ import print_function
import multiprocessing
# multiprocessing.set_start_method('spawn')
```
观察: 两个第三方 import(future, multiprocessing),都是 stdlib,不追。继续。

### 2026-04-09 15:33 — 读 train.py L4-L27
(列出读到的行,或摘要 + 关键行号)
发现 L27: `from utils.iTransformer.Transformer_EncDec import Encoder, EncoderLayer`
→ 这是本地依赖。push TODO: 读 `utils/iTransformer/Transformer_EncDec.py` 定位 `Encoder`, `EncoderLayer`
→ 当前 TODO (train.py) 暂停在 L27
→ 栈变为: [ Transformer_EncDec.py (active) | train.py (paused @ L27) ]

### 2026-04-09 15:34 — 读 utils/iTransformer/Transformer_EncDec.py L1-L10
...

(继续,每次读一小段 → 记录 → 发现依赖立刻 push → 栈状态即时反映在顶部 TODO 栈区)

## 已解决的依赖(Done)

- ✓ `utils/iTransformer/Transformer_EncDec.py` — 定义 Encoder/EncoderLayer,依赖 attention 模块(已追)
- ✓ `weights/best.pth` — 消费 `load_model.py:L22`,生产 `train.py:L340 torch.save(...)`
- ...

## Required files(场景 A: 推理 / 场景 B: 训练)

### 场景 A — 仅推理(复现论文图)
代码文件(行范围精确):
- `minimal_generate_image_v3.py` L1-end
- `utils/myfuncs/obtain_strain.py` L1-L87, L325-L381 (get_strain_data + split_strain_into_segments)
- `utils/myclass/mymodel.py` L1-end
- ...

资产:
- `config/config.yaml` 消费 entry L15 — 仓库自带 ✓
- `weights/best.pth` 消费 `load_model.py:L22` — HF 资产 ✓
- `BarrysMockTrain_paths.npz` 消费 `dataset.py:L55` — **生产者未知(BLOCKED)**

### 场景 B — 从零完整重训
(场景 A 的全部 + 训练数据生成 + 训练入口 + 生成 manifest + 真实 strain 下载)
...

## BLOCKED 清单(已尝试穷尽搜索,仍未定位)

### BLOCKED-1: `utils.myfuncs.save_output` 模块
- 消费: `train.py:L41 from utils.myfuncs.save_output import setup_csv, append_to_csv`
- 搜索尝试:
  1. `grep -rn "def setup_csv" /home/yguo173/Programs/ABONORMAL` → 0 命中
  2. `find / -name "save_output.py" 2>/dev/null` → 0 命中
  3. `grep -rn "setup_csv\|append_to_csv" external/` → 仅命中 train.py 的 import 本身
  4. 查 `utils/myfuncs/__init__.py` 是否 re-export → 未 re-export
- 假设: 原作者本地有但未提交,或该 import 从未被实际执行过
- 待用户回答: (a) 你那边是否有 save_output.py?(b) 要不要我写一个极简 csv.writer 包装?

## 第三方库清单(不展开)

torch / numpy / gwpy / pycbc / h5py / tqdm / pyyaml / scikit-learn / matplotlib
```

## Workflow (how to actually do this)

### Step 1 — Create the task directory and seed the trace file

```
artifacts/task_<name>/
├── <entry>_trace.zh.md   ← the single source of truth
```

Seed the trace file with the header and an initial TODO stack containing only the entry script as `[active]`. Then immediately begin reading the entry.

### Step 2 — The read/push/pop loop

Repeat until the TODO stack is empty (except for `[blocked]` items):

1. Look at stack top. If it's `[active]`, resume reading at the recorded line. If it's `[paused]`, mark it `[active]` and resume.
2. Read forward until you hit any external dependency (Rule 2) or EOF.
3. Append a new entry to "阅读轨迹" with timestamp, file, line range read, quoted or summarized content, and observations.
4. For each external dependency encountered in that read slice:
   - If it's an internal file/function → push a new TODO to the stack. Mark the current TODO as `[paused]` at the current line. The new TODO becomes `[active]`.
   - If it's a data asset / file path → push a "resolve producer for X" TODO.
   - If it's a third-party package → add to the third-party list at the bottom, no push needed.
5. **Immediately rewrite the "TODO 栈" section of the markdown to reflect the new stack state**. The stack at the top of the file is always the ground truth.
6. If the current file hits EOF or a clean "no more external deps below this point" conclusion → pop the current TODO into the "已解决" section, move up one stack frame, resume there.
7. If a TODO cannot be resolved after 3 exhaustive search strategies (Rule 5), mark it `[blocked]` with full search record, pop it (conceptually) to the blocked section, and continue with the next stack item. Do not halt the whole trace.

### Step 3 — Second pass on BLOCKED items

Once the main stack is drained and everything else is resolved, walk the `[blocked]` list once more. Sometimes later reads reveal context that unblocks earlier mysteries (e.g., a function turns out to be defined later in the same file you already read, or an asset name turns out to be dynamically constructed). Try once more per item with any new context you now have.

### Step 4 — Finalize Required files and report to user

Now that every reachable node is either resolved or genuinely blocked, fill in the "Required files" section with precise line ranges. For each file in the closure, re-scan your trace log to find which line ranges were actually traversed — those are the lines the entry needs.

Then report to the user with this structure:

1. **Verdict** — one sentence: "闭包完备 / N 个 BLOCKED 阻塞场景 B / 完全不可运行,见 BLOCKED-1 至 BLOCKED-K"
2. **Numbers** — files in closure, assets resolved, BLOCKED count
3. **BLOCKED questions** — the concrete questions only the user can answer (each BLOCKED-N item rewritten as a question)
4. **Trace file path** — so the user can read the full stack and reading log

Do not summarize the trace log inline. The trace file is the deliverable; the chat response just points at it and surfaces blockers.

## Anti-patterns

- **Batching reads and logging at the end.** By the time you write the log, details of read #2 are gone. Every read → immediately update the markdown. This is the #1 reason traces fail.
- **"Probably defined in some utils file."** No. Either you grepped and found it (log the command + result) or it's BLOCKED (log the 3 distinct search attempts). Never "probably".
- **Letting a BLOCKED item halt the trace.** BLOCKED means skip and continue, not stop. Only surface to user after full resolution pass.
- **Running the code to "just check."** The entire value of this skill is that it works when the code can't run. Once you run code, you've left the regime where the trace is trustworthy for a cold-start audit. Stay in the read-only regime unless the user explicitly says otherwise AND you've justified in the log why execution is load-bearing.
- **Forgetting the resume line.** Every `[paused]` frame must record the exact line number where reading was suspended. Otherwise resume is guessing.
- **Conflating "file fully read" with "dependencies fully resolved."** A file is only `Done` when all its local imports, function calls into other files, and disk I/O operations have either been recursed into or logged as BLOCKED.
- **Writing the Required files section all at once at the end from memory.** You've been reading for hours; your memory is wrong. Build it from your own trace log — the line ranges you actually read are the line ranges the closure needs.

## When to consult the user (not BLOCKED — real escalation)

BLOCKED means "skip for now". Escalation means "I genuinely need you". Escalate only when:

1. The trace diverges into multiple disconnected entry points inside the same script (e.g. `if __name__ == '__main__'` with mutually exclusive subcommands) and it's unclear which one the user actually cares about.
2. You've found what looks like a real bug in the entry (e.g. import from a module that has never existed in any reachable version of the repo, not just a missing one) — this may change the scope of the task.
3. After the second pass in Step 3, BLOCKED items remain and they sit on the critical path of Scenario A. (BLOCKED items only on Scenario B's path can be reported at the end without escalating.)

Escalate as concrete questions with option menus, never as "I'm stuck".
