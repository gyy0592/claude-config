#!/usr/bin/env python3
"""Append a human-readable entry to <session_dir>/transitions.log on every FSM transition.

Usage:
    python3 _transition_log_helper.py <sdir> <sid> <old_state> <new_state> <event> <reason> <ts>

Arguments
---------
sdir       : path to .barry_workflow/<sid>/  (the session directory)
sid        : session UUID
old_state  : e.g. BOOT
new_state  : e.g. PREPARE
event      : e.g. BOOT_DONE
reason     : free-form string from --reason=
ts         : ISO timestamp for this transition
"""

import sys
import json
import re
import glob
import pathlib
import textwrap

def _find_jsonl(sid: str) -> pathlib.Path | None:
    """Glob for ~/<sid>.jsonl anywhere under ~/.claude/projects/."""
    pattern = str(pathlib.Path.home() / ".claude" / "projects" / "*" / f"{sid}.jsonl")
    matches = glob.glob(pattern)
    return pathlib.Path(matches[0]) if matches else None


def _parse_jsonl(jsonl_path: pathlib.Path):
    """Return list of parsed dicts; skip unparseable lines silently."""
    entries = []
    for line in jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return entries


def _prev_transition_ts(log_path: pathlib.Path) -> str | None:
    """Read the most recent timestamp from transitions.log (first token of last entry)."""
    if not log_path.exists():
        return None
    text = log_path.read_text(encoding="utf-8", errors="replace")
    # Each entry starts with an ISO timestamp on a line that contains " → "
    ts_lines = [l for l in text.splitlines() if " → " in l and re.match(r"\d{4}-\d{2}-\d{2}T", l)]
    if not ts_lines:
        return None
    return ts_lines[-1].split()[0]


def _count_tools_since(entries: list, since_ts: str | None) -> dict:
    """Count tool_use blocks in assistant messages newer than since_ts."""
    counts: dict[str, int] = {}
    for obj in entries:
        if obj.get("type") != "assistant":
            continue
        obj_ts = obj.get("timestamp", "")
        if since_ts and obj_ts and obj_ts <= since_ts:
            continue
        content = obj.get("message", {}).get("content", [])
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                name = block.get("name", "unknown")
                counts[name] = counts.get(name, 0) + 1
    return counts


def _last_assistant_text(entries: list, since_ts: str | None, max_chars: int = 200) -> str:
    """Return last assistant text chunk before current transition, collapsed to one line."""
    last_text = None
    for obj in entries:
        if obj.get("type") != "assistant":
            continue
        obj_ts = obj.get("timestamp", "")
        if since_ts and obj_ts and obj_ts <= since_ts:
            continue
        content = obj.get("message", {}).get("content", [])
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                t = block.get("text", "")
                if t.strip():
                    last_text = t
    if last_text is None:
        return "(no text found)"
    # Collapse whitespace + truncate
    collapsed = " ".join(last_text.split())
    if len(collapsed) > max_chars:
        collapsed = collapsed[:max_chars - 3] + "..."
    # Escape inner double quotes so the line stays single-line readable
    collapsed = collapsed.replace('"', "'")
    return collapsed


def _fmt_tool_counts(counts: dict) -> str:
    """Format tool counts as '8 (Bash×3, Read×2, Edit×3)'."""
    total = sum(counts.values())
    if not counts:
        return "0"
    breakdown = ", ".join(f"{k}×{v}" for k, v in sorted(counts.items()))
    return f"{total} ({breakdown})"


def main():
    if len(sys.argv) < 8:
        print(
            "usage: _transition_log_helper.py <sdir> <sid> <old> <new> <event> <reason> <ts>",
            file=sys.stderr,
        )
        sys.exit(1)

    sdir, sid, old_state, new_state, event, reason, ts = sys.argv[1:8]
    log_path = pathlib.Path(sdir) / "transitions.log"

    # --- Line 1 always written ---
    line1 = f"{ts}  {old_state} → {new_state}  event={event}  reason=\"{reason}\""

    # --- Find JSONL ---
    jsonl_path = _find_jsonl(sid)
    if jsonl_path is None:
        entry = f"{line1}\n  tools_since_prev_transition: (no transcript yet)\n  last_assistant_text: (no transcript yet)\n"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(entry + "\n")
        return

    # --- Parse JSONL ---
    try:
        entries = _parse_jsonl(jsonl_path)
    except Exception as exc:
        entry = f"{line1}\n  tools_since_prev_transition: (transcript parse error: {exc})\n  last_assistant_text: (transcript parse error: {exc})\n"
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(entry + "\n")
        return

    # --- Determine cutoff timestamp ---
    prev_ts = _prev_transition_ts(log_path)

    # --- Compute metrics ---
    counts = _count_tools_since(entries, prev_ts)
    last_text = _last_assistant_text(entries, prev_ts)

    tools_str = _fmt_tool_counts(counts)

    entry = (
        f"{line1}\n"
        f"  tools_since_prev_transition: {tools_str}\n"
        f"  last_assistant_text: \"{last_text}\"\n"
    )

    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(entry + "\n")


if __name__ == "__main__":
    main()
