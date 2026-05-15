# RECORDING — dedicated ledger-writing state

You are in RECORDING. Sole purpose: scan the session's work, write any qualifying entries to project + global ledgers, then exit. No project source work allowed.

Entered via:
- `EXECUTE_EXIT` from EXECUTE_LOOP (mandatory — every loop exit passes through here before END)
- `NEED_RECORD` from REFLECT or EXECUTE_LOOP (voluntary mid-task; resume via `BACK_TO_LOOP`)

## Pipeline (do these in order)

### Step 1 — 4-question self-check

Read your action.md + recent tool outputs for this session. Answer each, in writing in action.md (`[RECORDING_SELF_CHECK]` block):

| # | Question | If yes → write to |
|---|---|---|
| 1 | 本会话碰到过 non-obvious 项目技术坑（lib 不兼容 / 配置组合 / 硬件怪癖 / OOM 模式 / 错误信息含义）? | `$PWD/workspace/bitter_lessons.md` — L-N entry with `task:` + `tags:` |
| 2 | 本会话有 fix 已经经过 retest 3-Q 验证成功? | `$PWD/workspace/successful_fixes.md` — FIX-N entry with before/after, `task:` + `tags:` |
| 3 | 本会话 AI 自己有过被 hook nudge / user 纠正 / 自己事后发现的违规（跳 dispatch / 漏 PLAN / 误 [INFERENCE] / record-skip / scope creep）? | `$PWD/workspace/rule_violations.md` — W-N entry with `task:` + `tags:` |
| 4 | 上述 1-3 任一项有跨项目意义（其他项目也会踩 / 也会犯）? | `content/templates/global_rules/{lessons,violation}.md` — L-XXX / W-XXX entry with `tags:` |

If all 4 are "no": write `[no new ledger entries]` to action.md.

### Step 2 — Attempts ledger (every visit)

Always append one ATT-N to `$PWD/workspace/attempts_ledger.md`：one-line intent log of what this session/turn did. Include `task:` + `tags:` lines.

(This is the cross-turn intent ledger — written every time RECORDING is entered, regardless of Step 1 answers.)

### Step 3 — Choose exit

- **`RECORD_DONE` → END** : default exit when this is the session-closing visit (entered via EXECUTE_EXIT). Next: state.md is updated to END, you write the final user-facing summary there.
- **`BACK_TO_LOOP` → prev state** : entered via NEED_RECORD mid-task; ledger written, resume execution. `prev_status` field in state.md restores the right state.

Pick based on whether the actual task work is done. If unsure, prefer `BACK_TO_LOOP` (cheap to re-enter; harder to undo a premature END).

## Allowed
- Read / Grep / Glob
- Bash(`ls`, `cat`, `head`, `tail`, `grep`, `wc`, `transition.sh`)
- Append-only Write/Edit to:
  - `$PWD/workspace/*.md` (4 shared ledgers — never overwrite, always append)
  - `content/templates/global_rules/*.md` (repo path; `set_claude.sh` deploys to `~/.claude/rules/`)
  - `$PWD/.barry_workflow/<sid>/action.md`

## Forbidden
- Project source mutations (any file outside workspace/ / .barry_workflow/ / content/templates/global_rules/)
- Direct Edit/Write to `~/.claude/rules/*` (use repo path — `preedit_global_rules_guard.sh` may hard-block this in a future patch)
- Agent spawn / new Bash work commands
- Starting fresh execution work — that's what `BACK_TO_LOOP` is for

## Closing criteria — ALL must be true before transition

- [ ] `[RECORDING_SELF_CHECK]` block in action.md answers all 4 questions
- [ ] If any question was "yes", the corresponding ledger has a new entry with `task:` + `tags:`
- [ ] ATT-N appended to attempts_ledger.md
- [ ] Exit event (RECORD_DONE or BACK_TO_LOOP) chosen with one-line reason

## Re-entry

RECORDING can be entered multiple times per session (mid-task NEED_RECORD as often as needed). Final visit (via EXECUTE_EXIT) should exit via RECORD_DONE → END.
