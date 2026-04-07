---
name: codex-fix
description: "Diagnostic and fix reference for Codex CLI failures. MUST read when: `codex review` fails with any error, bwrap sandbox errors appear (loopback / RTM_NEWADDR / Operation not permitted), stream disconnection occurs (Reconnecting... / stream disconnected before completion), codex hangs or exits unexpectedly, or any `codex` subcommand behaves differently from `codex exec`. Also triggers on: bubblewrap, bwrap, sandbox, user namespace, subuid, subgid, codex review broken, codex stream, diff too large, CRS proxy, codex exit."
---

# Codex CLI — Fix Reference

Read only the section that matches the error. Do not apply multiple fixes at once.

---

## Error 1 — bwrap sandbox failure

**Symptoms** (any of these):
```
bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted
bwrap: setting up uid map: Permission denied
```

**Root cause:** `codex review` uses bubblewrap (bwrap) to create a read-only sandbox. Requires:
1. `bwrap` binary present with the setuid bit set
2. User namespace mappings (`/etc/subuid`, `/etc/subgid`) available

**Fix:**
```bash
# 1. Install bubblewrap and uidmap (Debian/Ubuntu)
sudo apt install -y bubblewrap uidmap

# 2. Set the setuid bit so non-root users can create user namespaces
sudo chmod u+s /usr/bin/bwrap

# 3. Verify
bwrap --version   # expected: bubblewrap 0.x.x
which bwrap       # expected: /usr/bin/bwrap
```

**Verify fix:**
```bash
HUMANIZE_CODEX_BYPASS_SANDBOX=true codex review --commit <sha>
```

---

## Error 2 — Stream disconnected before completion

**Symptoms:**
```
ERROR: Reconnecting... 1/5 ... 5/5
ERROR: stream disconnected before completion
```

**Step 1 — Retry first (network blip vs structural problem)**

Before changing anything, retry the exact same command up to 3 times. Network jitter often causes a single disconnect; a clean retry succeeds within 1-2 attempts.

```bash
# Retry the original command — do this up to 3 times before assuming a structural issue
<original codex command>
```

If it succeeds on retry: done, no further action needed.
If it fails all 3 attempts consistently: proceed to Step 2.

**Step 2 — Check diff size**

```bash
git diff <base>..<head> | wc -l
```

- **< 1000 lines and still failing**: likely a persistent network/proxy issue. Wait a few minutes and retry again. If still failing after 5 total attempts, escalate to the user.
- **≥ 1000 lines**: the diff is too large for the stream. Switch strategies below.

**Step 3 — Switch strategies (only if diff ≥ 1000 lines)**

**Fix A — Review commit-by-commit (preferred):**
```bash
# Reviews one commit at a time; each diff is small enough to avoid timeout
codex review --commit <sha>
```

**Fix B — Use `codex exec` for large diffs:**
```bash
# codex exec uses a stable stream; no disconnection even on large prompts (~72 KB+)
git diff <base>..<head> | codex exec --model gpt-5.4 "review this diff for issues"
```

**When to use which:**
- `--commit` is the clean path — use it for structured code review
- `codex exec` is the escape hatch — use it when you need to pipe arbitrary content or when `codex review` is unavailable

---

## Quick Diagnostic Checklist

If the error does not match either case above, run through this before escalating:

1. **Which subcommand failed?** `codex review` vs `codex exec` behave very differently — only `review` uses bwrap.
2. **Is bwrap installed and setuid?** `ls -la $(which bwrap)` — look for `-rwsr-xr-x`.
3. **How large is the diff?** `git diff <base>..<head> | wc -l` — above ~1000 lines risks stream timeout.
4. **Environment variables set correctly?** `echo $HUMANIZE_CODEX_BYPASS_SANDBOX` — should be `true` if bypassing sandbox.
5. **tmux session clean?** Stale `TMUX_*` env vars can cause unexpected behavior — unset them or open a fresh session.
