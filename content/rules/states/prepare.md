# PREPARE — preparation

You are in PREPARE. Before doing any work, build a complete picture of inputs, expected outputs, applicable patches, and explicit success criteria.

## Pipeline (do these in order)

### Step 1 — Run prepare helper

```
bash ~/.claude/hooks/prepare_helper.sh
```

Output sections:
- `cache_hit_map` stub — every artifact under `workspace/` + `.barry_workflow/` listed with sha1 + `hit: UNKNOWN`
- 4-element prompt-reinforcement checklist

### Step 2 — Fill cache_hit_map

For each row in the stub, replace `UNKNOWN` with:
- `YES` — already in your KV cache from a prior turn this session (no Read needed)
- `NO` — must Read this turn

Paste the filled YAML into `state.md` `cache_hit_map:` block.

**Misjudgment** (claiming YES when actually NO) = AI behavioral error → write to `rule_violations.md` if caught later.

### Step 3 — Read every NO row

For each `NO` row, Read the file. Tag any claims drawn from Reads using `[FACT]/[INFERENCE]/[ASSUMPTION]` per `facts_first.md`.

### Step 4 — 4-element prompt enhancement

Verify the user instruction has all 4 elements; for any missing, write `[PROMPT_REINFORCED]` to action.md noting which is missing + your proposed default (defaults table in `prompt_enhancement.md`).

| element | meaning | failure mode if absent |
|---|---|---|
| observable | what signal proves success | EXECUTE can't write meaningful [OBSERVE] |
| cadence | how often to check | self-spin polling or under-monitor |
| reflection | when to spawn REFLECT | post-task verification skipped |
| completion | when to stop | "claimed done" without real check |

Skip Step 4 if `[BOOT_NOTE complexity=simple]` — see `patches/simple_fast.md`.

### Step 5 — Scan applicable patches

Based on BOOT complexity classification, Read matching `~/.claude/rules/patches/*.md`:

| complexity | patches to Read |
|---|---|
| `simple` | patches/simple_fast.md (may permit skipping pre-task REFLECT) |
| `normal` | (none required) |
| `long_monitor` | patches/long_monitor.md (cadence T_queue/5 → T_run/20 → T_run/5) |
| `bug_debug` | patches/bug_debug.md (reproduce-before-fix; 3-anomaly mandatory on-anomaly REFLECT) |
| `perf_debug` | patches/perf_debug.md (measure baseline first; one variable at a time) |
| `explore` | patches/exploration.md (forces pre-task REFLECT N=2 rebuttal rounds) |

### Step 6 — Draft plan into action.md

Append a `[PLAN]` block to action.md:

```
[PLAN @ ts]
intended deliverable: <one line>
success criteria:
  - <bulleted>
risk areas:
  - <bulleted>
patches applied: <comma-list or "none">
```

## Allowed
- Read / Glob / Grep / WebSearch
- Bash: `prepare_helper.sh`, `transition.sh`, `ls`, `cat`, `head`, `tail`, `wc`, `grep`, `jq`
- Append-only writes to action.md (planning notes only — no project source edits)

## Forbidden
- Edit / Write to project source files
- Spawning execution agents (Agent for real work — that's EXECUTE_LOOP)
- Starting bg jobs
- Running tests / deploys / scripts that mutate state

## Completion criteria — ALL must be true before advancing

- [ ] cache_hit_map fully resolved (no `UNKNOWN` rows)
- [ ] all `NO` rows Read this turn
- [ ] 4 elements verified or PROMPT_REINFORCED written (skippable for `simple`)
- [ ] applicable patch(es) Read per complexity class
- [ ] `[PLAN]` block in action.md

## Advance

```
bash ~/.claude/hooks/transition.sh PREPARE_DONE --reason="<short>"
```

→ Next state: REFLECT (pre-task rebuttal). The transition script will cat `states/reflect.md` so you immediately see the next pipeline.
