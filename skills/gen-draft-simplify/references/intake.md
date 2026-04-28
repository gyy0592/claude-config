# Intake — Stage 0 AskUserQuestion template

This is the FIRST and ONLY interaction before any execution begins. Send a single `AskUserQuestion` call with all of the following items grouped together. Do not split into multiple turns.

If the user answers any item with "you decide" / "default" / "随便", record that exact answer and proceed with the documented default for that item. If the user leaves an item blank or unaddressed, mark it `⚠ not specified` in the instantiated draft and pause until they fill it in.

## Required questions

| Key | Question (paraphrase) | Format | Default if user defers |
|---|---|---|---|
| `REPO_PATH` | absolute path of the repository to refactor | open text | none — must be answered |
| `LANGUAGE` | main implementation language | open text or single-select | infer from file extensions, confirm |
| `ENTRY_SCRIPT` | which script reproduces canonical behavior | open text | none — must be answered |
| `BASELINE_CMD` | exact command to run the entry script and produce reference outputs | open text | none — must be answered |
| `BASELINE_OUTPUT_DIR` | where the entry script writes its outputs | open text | none — must be answered |
| `KNOWN_EXTERNAL_FUNCS` | external function families known up-front (e.g. `km*`, vendor SDK) | open text, comma-separated | empty (will be populated by scanning) |
| `PROTECTED_BLOCKS` | code that must NEVER be modified (GPU kernels / Triton / cython / vendored precompiled) | open text or multi-select | empty — but warn the user that GPU/Triton modules unprotected = risk |
| `ASK_TOOLS` | which `ask-*` tools to use for the per-modification mindtest (multi-select) | multi-select: `ask-claude`, `ask-gemini`, `ask-codex` | `ask-claude` only |
| `ASK_TOOL_SCRIPT_DIR` | absolute directory containing the `ask-<tool>.sh` shell scripts. Subagents must invoke the scripts via Bash — calling `humanize:ask-*` through the Skill tool returns driver instructions inline rather than executing the model (verified 2026-04-27 minimal-unit eval). This placeholder propagates the actual invocation path into the draft so subagents do not have to discover it themselves. | open text | auto-detect by probing in order: `~/Programs/humanize/scripts/`, then `~/.claude/plugins/cache/PolyArch/humanize/<latest>/scripts/`. If neither exists, mark `⚠ not found` and ask the user. |
| `PERF_MONITOR_INTERVAL_SEC` | seconds between in-script `nvidia-smi`+`psutil` snapshot prints | integer | `5` |
| `ROUND_AGENT_COUNT` | parallel subagents per round | integer | `8` |
| `REPORT_DETAIL_REF` | path to an existing report sample whose granularity should be matched | open text | empty — main thread generates one in Stage 1 |

## How to phrase the question call

Send a single `AskUserQuestion` with one question item per row above, grouped under one heading like "Repo-simplify intake — please fill all that apply". Use `multiSelect: true` for `ASK_TOOLS` and `PROTECTED_BLOCKS` (latter as free-text-array if the form supports it; otherwise open text).

The why: a single batched call respects the user's time and avoids the situation where the skill keeps coming back with "just one more question". It also forces the implementer to think about all parameters at once, surfacing missing ones early.

## After the answers come back

1. Validate that `REPO_PATH` exists and is a git repo with clean worktree. If not clean → ask the user whether to abort or stash.
2. Validate `BASELINE_CMD` runs to completion in the user's environment and produces files in `BASELINE_OUTPUT_DIR`. Record runtime + peak resource usage; this is the perf baseline.
3. Validate `ENTRY_SCRIPT` exists and is referenced by `BASELINE_CMD`.
4. If `PROTECTED_BLOCKS` is empty AND the repo contains files matching `*.cu`, `*kernel*`, `triton`, `cython` → loop back and warn the user before proceeding.
5. Hand off to Stage 1 (`references/draft_template.md`) with all values resolved.

If any validation fails, do NOT proceed to Stage 1. Report the failure and ask how to handle it.
