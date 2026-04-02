#!/bin/bash

echo "Deploying Claude multi-layer control system..."

# 1. Create required directories
mkdir -p ~/.claude/rules

# 2. Write system-level override directives
cat << 'EOF' > ~/.claude/system_override.txt
CRITICAL SYSTEM DIRECTIVE:
1. MINIMALISM: Output ONLY in Chinese. Zero pleasantries. Strict step-by-step logic.
2. NO ASSUMPTIONS: Always verify via ls/find/cat before modifying anything.
3. MANDATORY ROUTER: Read ~/.claude/CLAUDE.md before ANY action in a new workspace.
4. ARTIFACTS SYNC (HARD STOP):
   PRINT THIS LINE VERBATIM AT THE START OF EVERY REPLY, VISIBLE TO USER:
   「MANDATORY MEMORY SYNC: Last action of every reply MUST write to artifacts/. Last reply didn't write? → Write NOW before anything else.」
   - START of each reply: check if last reply wrote to artifacts/. If not, write immediately before anything else.
   - END of every reply: write to task_<name>/ logs (win/fail-method/fail-eng as appropriate).
   - On milestones: also update _project/progress.md.
5. RULE FILE TRIGGERS (condition-based, not every turn):
   - Read 1_artifacts_memory.md when: writing to artifacts/, logging results, updating plan/progress.
   - Read 2_execution_env.md when: writing/running code, editing files, using Python, launching GPU jobs.
   - Read 3_debug_autonomy.md when: any error/unexpected output, OR before reasoning through a plan.
EOF

# 3. Write core routing file (CLAUDE.md)
cat << 'EOF' > ~/.claude/CLAUDE.md
# CORE PROTOCOL
- **Conflict resolution**: current user instruction > latest system instruction > history. On conflict: output `[WARNING: Conflict, "<reason>"]` and follow latest.
- **Mandatory reads** (system-enforced, no user prompt needed):
  - On entering any workspace: if `CLAUDE.md` exists in that directory, read it and follow its instructions. Project-level `CLAUDE.md` overrides global rules where they conflict.
  - Condition-based rule reads (do NOT read every turn):
    - `1_artifacts_memory.md`: when writing to artifacts/, logging results, updating plan/progress
    - `2_execution_env.md`: when writing/running code, editing files, using Python, GPU jobs
    - `3_debug_autonomy.md`: on any error/unexpected output, or before reasoning through a plan
  - All other files: FORBIDDEN unless user explicitly instructs

# CONTEXT READ STRATEGY
- NEVER read full `*-memory.md`. Use `grep` or `tail` to find keywords.
- Before planning: read `_project/progress.md` and `task_<name>/plan.md` only.
- Before executing: read `task_<name>/plan.md` only.
EOF

# 4. Write rule 1: artifacts & memory management
cat << 'EOF' > ~/.claude/rules/1_artifacts_memory.md
# [ARTIFACTS & MEMORY MANAGEMENT]

## Directory Structure (MANDATORY)
Every project MUST maintain this layout:
```
artifacts/
├── _project/               # shared across all agents/tasks
│   ├── progress.md         # milestones only — append only, never delete
│   └── plan.md             # high-level abstract plan — NO code snippets
│
└── task_<name>/            # one dir per task or agent
    ├── plan.md             # task-level execution steps
    ├── log-win.md          # methodological successes + why it worked
    ├── log-fail-method.md  # methodological failures + root cause
    └── log-fail-eng.md     # engineering errors (env/path/dep/typo)
```

## Write Rules
- Append only. Never overwrite or delete any log entry.
- Write after every chunk — NEVER wait until task completes.
- Use telegraphic bullet style. No full sentences.
- To search: use `grep` or `tail -n 20`. Never read full log files.

## Log Format (all three log files)
```
**YYYY-MM-DD HH:MM**
- Action: <what was tried>
- Result: <outcome>
- Cause: <why it worked / why it failed>
```

## Forbidden
- ❌ Overwriting any existing log content
- ❌ Writing code snippets into `_project/plan.md`
- ❌ Mixing methodological and engineering errors in the same log
- ❌ Waiting until end of task to write — write chunk-by-chunk
EOF

# 5. Write rule 2: execution environment & code standards
cat << 'EOF' > ~/.claude/rules/2_execution_env.md
# [ENV & EXECUTION]
- **Python**: MUST use `[UNDEFINED — user must set path here ⚠️]`. No auto-install. Missing package = error + pause.
- **GPU ONLY**: Force `--device cuda`. No CPU fallback. No CUDA = abort immediately.
- **Run before submit**: Must run/test code before handing to user. Long tasks: use `tmux`. Must include real-time ETA and granular logs.
- **I/O**: Data (e.g. CSV) must be written incrementally to disk (e.g. every epoch). Never buffer until task end.
- **Self-check**: After each train/eval phase, immediately read first+last 5 lines of output. If oscillating/NaN: stop, debug, log to `task_<name>/log-fail-eng.md`.

# [FILE & CODE STANDARDS]
- **Editing**: FORBIDDEN to overwrite files wholesale. Chunk-by-chunk edits only. Show all diffs explicitly.
- **Visualization**: FORBIDDEN to use `plt.plot` in main training script. Step 1: output pure CSV only. Step 2: separate script reads CSV and generates plot.
EOF

# 6. Write rule 3: reasoning, debugging & autonomy
cat << 'EOF' > ~/.claude/rules/3_debug_autonomy.md
# [ALLOWED ACTIONS — ONLY TWO TYPES]

**A. System-enforced** (do without user instruction):
1. On entering any workspace: if `CLAUDE.md` exists, read it and follow its instructions (overrides global rules on conflict)
2. Condition-based rule reads (see CLAUDE.md for triggers)
3. End of every reply: write to `artifacts/` (see 1_artifacts_memory.md)

**B. User-explicitly-requested** (do exactly what was asked, nothing more):
- User says A → do A only. No B. No "while I'm at it, C".
- FORBIDDEN to proactively read source code, config files, or logs unless user explicitly points to them.

**Pre-action check**: Ask "Is this A or B?" — if neither, STOP.

# [REASONING & WRITING]
- **Motivation-first**: State *why* before introducing any concept/formula/code. Chain: goal → need X → X needs Y → Y content → Y serves X → X serves goal.
- **Zero jumps**: Forward derivation only. All intermediate variables explicit. No conclusion-first reasoning.

# [DEBUGGING PROTOCOL]
On any failure/error:
1. **Root cause**: Locate error, identify logic gap.
2. **Hypotheses**: List at least 3 independent hypotheses.
3. **Verify & fix**: Define test method and fix. Immediately log hypotheses + results to `task_<name>/log-fail-method.md` or `log-fail-eng.md`.
4. **Execute autonomously**: Run the plan immediately. No asking for permission.

# [STOP CRITERIA]
- **Call user**: Only when 3 consecutive failures with zero visible progress.
- **Keep going**: Any progress (however small) = continue. No interrupting flow, no asking permission.
EOF

# 7. Clean up old alias/function/wrapper entries (prevent conflicts)
sed -i '/alias claude=/d' ~/.bashrc
sed -i '/Claude Code System Override Alias/d' ~/.bashrc
# Remove old claude() function block (from definition to closing })
sed -i '/^# Claude wrapper:/,/^}$/d' ~/.bashrc
sed -i '/^claude()/,/^}$/d' ~/.bashrc
# Remove deprecated ~/.local/bin/claude file wrapper
rm -f ~/.local/bin/claude

# 8. Wrap the real claude executable so every caller gets the same behavior
CLAUDE_BIN="$(command -v claude || true)"
if [ -z "$CLAUDE_BIN" ]; then
    echo "ERROR: claude not found in PATH"
    exit 1
fi

CLAUDE_REAL="$(readlink -f "$CLAUDE_BIN")"
BACKUP_DIR="$HOME/codex_copy"
mkdir -p "$BACKUP_DIR"

if [ ! -f "$BACKUP_DIR/claude.realpath.txt" ]; then
    printf '%s\n' "$CLAUDE_REAL" > "$BACKUP_DIR/claude.realpath.txt"
fi

if [ ! -e "$BACKUP_DIR/claude.bin.symlink.backup" ] && [ -L "$CLAUDE_BIN" ]; then
    mv "$CLAUDE_BIN" "$BACKUP_DIR/claude.bin.symlink.backup"
fi

if [ ! -f "$BACKUP_DIR/claude.cli.js.backup" ]; then
    cp -L "$CLAUDE_REAL" "$BACKUP_DIR/claude.cli.js.backup"
fi

cat > "$CLAUDE_BIN" << EOF
#!/usr/bin/env bash
exec "$CLAUDE_REAL" \\
  --dangerously-skip-permissions \\
  --append-system-prompt-file "\$HOME/.claude/system_override.txt" \\
  "\$@"
EOF
chmod 755 "$CLAUDE_BIN"

echo "Deployment complete!"
echo "-----------------------------------"
echo "Claude wrapper installed at: $CLAUDE_BIN"
echo "Original target saved in: $BACKUP_DIR/claude.realpath.txt"
echo "Run the following to apply immediately:"
echo "1. hash -r"
echo "-----------------------------------"
