# Format Rules — Code Tree

These rules exist because a previous version of this document had real rendering bugs caused by violating them. Read before writing a single line.

---

## Rule 1: Never nest `<details>` blocks

Each function gets exactly **one** `<details>` block — the `🔍 Technical details` block. It opens after the Output line and closes before the Call chain section. There is no second `<details>` inside it.

Why this matters: nested `<details>` breaks GitHub Markdown rendering silently — the outer block appears to close, but the document structure is corrupt.

Self-check: after writing each function, count `<details>` openings and `</details>` closings for that function — they must be equal, and both must equal 1.

---

## Rule 2: Input/Output are always-visible human sentences

**Input** and **Output** lines sit outside any `<details>` block. A reader browsing the document should understand what every function does without expanding anything.

❌ Wrong (put inside details, or is a variable list):
```
**Input**: `hf_home`: str, HuggingFace cache root
```

✅ Right (outside details, plain prose):
```
**Input**: Accepts the HuggingFace local cache root and a model ID, used to locate the weight shard directory of the downloaded model.
```

Variable names and types belong in the `🔍 Technical details` block, not in the visible Input/Output.

---

## Rule 3: Every `### 功能N` must have a `#### 调用树` first

The ASCII call tree comes immediately after the `### 功能N` heading, before any function docs. It shows the full entry→leaf call hierarchy for that functional area.

ASCII call tree characters: `└──` `├──` `│` for structure; `←` for "this is in file X"; `→` for "writes to path Y".

---

## Rule 4: Every function needs an HTML anchor

The anchor `<a id="function_name"></a>` goes on the line immediately before the `####` heading. The anchor name is the snake_case function name. The Call chain section references it as `[function_name()](#function_name)`.

---

## Rule 5: Write incrementally

Write each function's documentation to the output file immediately after reading that function's source code. Do not buffer everything in memory and write at the end — this risks losing work and makes progress invisible.
