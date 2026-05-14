#!/usr/bin/env python3
"""
extract_transcript.py — turn a Claude Code session JSONL into a clean,
human-readable conversation log.

Input:  one or more JSONL files (~/.claude/projects/<encoded-cwd>/<sid>.jsonl)
        OR stdin if no args.

Output: plain text on stdout, one "block" per role/turn:

    ── USER ─── ts ───
    <text>

    ── ASSISTANT ─── ts ───
    <text>

    ── TOOL_USE [Bash bash_id=...] ───
    command: <…>            # or `input: {...}` for other tools
    description: <…>

    ── TOOL_RESULT [bash_id=...] (truncated to N lines) ───
    <stdout/stderr>

Flags:
    --tool-result-lines N   truncate each tool result to N lines (default 20).
    --no-system-reminder    drop <system-reminder> blocks (kept by default).
    --tools-only            print only tool_use + tool_result, skip prose.
    --raw-text              don't pretty-print, just dump role + text without
                            tool details (good for grep).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SYS_REMINDER_RE = re.compile(
    r"<system-reminder>.*?</system-reminder>\s*", re.DOTALL
)


def text_of(content) -> str:
    """Pull human-visible text out of a content list or string."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    out = []
    for part in content:
        if isinstance(part, dict) and part.get("type") == "text":
            out.append(part.get("text", ""))
    return "\n".join(out).strip()


def fmt_tool_input(name: str, tool_input: dict) -> str:
    """Compact one-line-ish summary of a tool call's input."""
    if not isinstance(tool_input, dict):
        return repr(tool_input)
    if name == "Bash":
        parts = []
        cmd = tool_input.get("command")
        if cmd:
            parts.append(f"command: {cmd}")
        desc = tool_input.get("description")
        if desc:
            parts.append(f"description: {desc}")
        if tool_input.get("run_in_background"):
            parts.append("run_in_background: true")
        return "\n".join(parts)
    if name == "Read":
        return f"path: {tool_input.get('file_path')}"
    if name == "Edit":
        return (
            f"path: {tool_input.get('file_path')}\n"
            f"old_string: {repr(tool_input.get('old_string',''))[:200]}\n"
            f"new_string: {repr(tool_input.get('new_string',''))[:200]}"
        )
    if name == "Write":
        return (
            f"path: {tool_input.get('file_path')}\n"
            f"content (first 200 chars): "
            f"{repr((tool_input.get('content') or '')[:200])}"
        )
    if name == "Agent":
        return (
            f"subagent_type: {tool_input.get('subagent_type')}\n"
            f"description: {tool_input.get('description')}\n"
            f"run_in_background: {tool_input.get('run_in_background')}\n"
            f"prompt (first 300 chars): "
            f"{repr((tool_input.get('prompt') or '')[:300])}"
        )
    # generic fallback
    s = json.dumps(tool_input, ensure_ascii=False)
    return s if len(s) <= 400 else s[:400] + " …(truncated)"


def fmt_tool_result(content, max_lines: int) -> str:
    """Tool results: prefer .content list with text type; truncate."""
    if isinstance(content, list):
        chunks = []
        for part in content:
            if isinstance(part, dict):
                chunks.append(part.get("text", part.get("content", "")))
            else:
                chunks.append(str(part))
        text = "\n".join(c for c in chunks if c)
    elif isinstance(content, str):
        text = content
    else:
        text = json.dumps(content, ensure_ascii=False)
    lines = text.splitlines()
    if max_lines and len(lines) > max_lines:
        head = "\n".join(lines[:max_lines])
        return f"{head}\n…[truncated {len(lines) - max_lines} more lines]"
    return text


def iter_entries(paths: list[Path]):
    if not paths:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue
        return
    for p in paths:
        with p.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--tool-result-lines", type=int, default=20)
    ap.add_argument("--no-system-reminder", action="store_true")
    ap.add_argument("--tools-only", action="store_true")
    ap.add_argument("--raw-text", action="store_true")
    args = ap.parse_args()

    # cache tool_use_id → tool name (for prettier tool_result headers)
    name_by_id: dict[str, str] = {}

    for entry in iter_entries(args.files):
        etype = entry.get("type", "")
        ts = entry.get("timestamp", "")
        msg = entry.get("message", entry)

        # User turns + tool_results live under role=user
        if etype == "user" or msg.get("role") == "user":
            content = msg.get("content")
            # tool_result?
            if isinstance(content, list):
                tool_result_parts = [
                    c for c in content if isinstance(c, dict) and c.get("type") == "tool_result"
                ]
                user_text_parts = [
                    c for c in content if isinstance(c, dict) and c.get("type") == "text"
                ]
                for tr in tool_result_parts:
                    tid = tr.get("tool_use_id", "")
                    tool_name = name_by_id.get(tid, "?")
                    if args.raw_text:
                        continue
                    print(f"\n── TOOL_RESULT [{tool_name} id={tid[-8:] if tid else '?'}] ───")
                    print(fmt_tool_result(tr.get("content", ""), args.tool_result_lines))
                if user_text_parts and not args.tools_only:
                    body = "\n".join(p.get("text", "") for p in user_text_parts).strip()
                    if args.no_system_reminder:
                        body = SYS_REMINDER_RE.sub("", body).strip()
                    if body:
                        print(f"\n── USER ─── {ts} ───")
                        print(body)
            elif isinstance(content, str) and not args.tools_only:
                body = content
                if args.no_system_reminder:
                    body = SYS_REMINDER_RE.sub("", body).strip()
                if body:
                    print(f"\n── USER ─── {ts} ───")
                    print(body)
            continue

        if etype == "assistant" or msg.get("role") == "assistant":
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            text_parts = [c for c in content if isinstance(c, dict) and c.get("type") == "text"]
            tool_uses = [c for c in content if isinstance(c, dict) and c.get("type") == "tool_use"]
            for t in tool_uses:
                tid = t.get("id", "")
                name = t.get("name", "?")
                name_by_id[tid] = name
            if text_parts and not args.tools_only:
                body = "\n".join(p.get("text", "") for p in text_parts).strip()
                if body:
                    print(f"\n── ASSISTANT ─── {ts} ───")
                    print(body)
            for t in tool_uses:
                if args.raw_text:
                    continue
                name = t.get("name", "?")
                tid = t.get("id", "")
                print(f"\n── TOOL_USE [{name} id={tid[-8:] if tid else '?'}] ───")
                print(fmt_tool_input(name, t.get("input", {})))
            continue

        # system / tool_result-as-top-level / summary entries — skipped silently


if __name__ == "__main__":
    main()
