# Step 3 — Document Generation Templates

The output document has four parts. Write them in order, incrementally to the output file.

---

## Part 1 — Title and project overview

````markdown
# Code Tree — <Project Name>

## Overview

<2-4 sentence description of what the project does and why>

**Key components**: <model names, dataset names, architecture details if relevant>

**N experimental stages**:
1. **Stage 1**: <one-sentence description>
...
````

---

## Part 2 — Directory structure

Use a fenced code block with the full directory tree. Annotate each important file with a `# comment` explaining its role:

```
project/
├── code/
│   ├── stage1/
│   │   ├── launcher.py       # Multi-GPU launcher
│   │   └── run_batch.py      # Per-GPU worker (main logic)
...
```

---

## Part 3 — Functional areas with call trees and function docs

For each functional area, follow this exact structure:

````markdown
### 功能N: <Area Name>

#### 调用树

```
entry_file.py: main()                     ← CLI entry point
└── _main_body(args, config_path, dir)
    ├── helper_a(x, y)                    ← helper_file.py
    │   └── sub_helper()                  → output/path/*.npz
    └── subprocess → worker.py: main()   ← each GPU spawns one
        ├── function_b()                  ← hooks.py
        └── function_c()                  → records/tokens/*.npz
```

---

#### Entry: `code/stage1/launcher.py`

---

<a id="function_name"></a>

#### `function_name(arg1, arg2)` — `code/stage1/file.py:42`

**Summary**: One sentence describing what it does.

**Motivation**: Why this function exists — what problem it solves or what design choice it encodes.

**Input**: Plain human sentence — what it accepts, where the data comes from, and what role it plays. Never a variable list here. Always visible.

**Output**: Plain human sentence — what it returns or writes, and how callers use it. Always visible.

<details>
<summary>🔍 Technical details (parameters · code)</summary>

**Parameters**:
- `arg1`: type, description
- `arg2`: type, description

**Returns**: type, description

```python
# Line 47-48: key implementation detail
some_code = here
```

</details>

**Call chain**:
- Called by [`caller_function()`](#caller_name) (`file.py:133`)
- Calls → [`callee_function()`](#callee_name) (`other_file.py:27`)

---
````

Repeat for every function in this functional area, then move to the next `### 功能N`.

---

## Part 4 — Cross-module data flow diagram

A plain-text diagram (using `─`, `►`, `│`, `┌`, `└`, `┐`, `┘`) showing how data flows between stages:

```
Stage 1 → records/*.npz → Stage 2 → bias_vectors.npz → Stage 3 → ...
```
