#!/usr/bin/env python3
"""Barry's Workflow viewer — local dynamic server.

Serves the viewer/ static files plus a small JSON API that reads from
`<cwd>/.barry_workflow/<sid>/`, `<cwd>/workspace/`, and the Claude Code
transcript JSONL under `~/.claude/projects/<encoded-cwd>/<sid>.jsonl`.

Usage:
    python3 viewer_server.py --cwd <path> [--port 0] [--host 127.0.0.1]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


VIEWER_DIR = Path(__file__).resolve().parent
SAFE_NAME = re.compile(r"^[A-Za-z0-9._\-]+$")
SAFE_REL  = re.compile(r"^[A-Za-z0-9._\-/]+$")


def encode_cwd_for_claude(cwd: Path) -> str:
    """Map an absolute cwd to the dir name Claude Code uses under ~/.claude/projects/.

    Claude Code replaces every non-alphanumeric character ( '/', '_', '.', etc.)
    with a single '-' and prepends a leading '-'. The resulting dir may not
    exist yet — caller should fall back to a glob if so.
    """
    s = str(cwd.resolve())
    enc = re.sub(r"[^A-Za-z0-9]", "-", s)
    if not enc.startswith("-"):
        enc = "-" + enc
    return enc


def find_transcript_path(cwd: Path, sid: str) -> Path | None:
    """Locate <sid>.jsonl under ~/.claude/projects/<encoded>/.

    Tries the canonical encoding first; falls back to scanning all
    ~/.claude/projects/*/<sid>.jsonl in case the local encoding rule drifts.
    """
    proj = Path.home() / ".claude" / "projects"
    cand = proj / encode_cwd_for_claude(cwd) / f"{sid}.jsonl"
    if cand.is_file():
        return cand
    if proj.is_dir():
        for d in proj.iterdir():
            p = d / f"{sid}.jsonl"
            if p.is_file():
                return p
    return None


def parse_state_md(text: str) -> dict:
    """Pull a few fields out of state.md's ---YAML--- block."""
    out: dict = {"current_status": None, "prev_status": None, "stage_history": []}
    m = re.search(r"---YAML---\s*\n(.*?)\n---YAML---", text, re.S)
    body = m.group(1) if m else text
    cs = re.search(r"^current_status:\s*(\S+)", body, re.M)
    if cs:
        out["current_status"] = cs.group(1).strip()
    ps = re.search(r"^prev_status:\s*(\S+)", body, re.M)
    if ps:
        out["prev_status"] = ps.group(1).strip()
    sh = re.search(r"^stage_history:\s*\n((?:[ \t].*\n)+)", body, re.M)
    if sh:
        for line in sh.group(1).splitlines():
            mm = re.match(r"\s*-\s*\{(.+)\}\s*$", line)
            if not mm:
                continue
            kv = {}
            # naive but adequate for `{event: X, to: Y, at: Z, reason: "..."}`
            for part in re.findall(r'(\w+):\s*("[^"]*"|[^,}]+)', mm.group(1)):
                k, v = part[0], part[1].strip().strip('"')
                kv[k] = v
            out["stage_history"].append(kv)
    return out


def list_sessions(cwd: Path) -> list[dict]:
    bw = cwd / ".barry_workflow"
    if not bw.is_dir():
        return []
    out = []
    for d in sorted(bw.iterdir(), key=lambda p: p.stat().st_mtime if p.exists() else 0, reverse=True):
        if not d.is_dir():
            continue
        st = d / "state.md"
        if not st.is_file():
            continue
        try:
            parsed = parse_state_md(st.read_text(encoding="utf-8", errors="replace"))
        except Exception:
            parsed = {"current_status": None, "stage_history": []}
        out.append({
            "sid": d.name,
            "mtime": int(st.stat().st_mtime),
            "current_status": parsed.get("current_status"),
            "transitions": len(parsed.get("stage_history") or []),
        })
    return out


def list_session_files(cwd: Path, sid: str) -> dict:
    d = cwd / ".barry_workflow" / sid
    if not d.is_dir():
        return {"exists": False}
    reflections = sorted([p.name for p in d.glob("reflection_*.md")])
    return {
        "exists": True,
        "has_state": (d / "state.md").is_file(),
        "has_action": (d / "action.md").is_file(),
        "has_transitions": (d / "transitions.log").is_file(),
        "reflections": reflections,
    }


def list_workspace(cwd: Path) -> dict:
    ws = cwd / "workspace"
    out = {"ledgers": [], "tasks": []}
    if not ws.is_dir():
        return out
    LEDGERS = ("bitter_lessons.md", "successful_fixes.md", "rule_violations.md", "attempts_ledger.md")
    for name in LEDGERS:
        p = ws / name
        if p.is_file():
            out["ledgers"].append({"name": name, "size": p.stat().st_size})
    for sub in sorted(ws.iterdir()):
        if sub.is_dir() and (sub / "goal.md").is_file():
            out["tasks"].append({"name": sub.name, "size": (sub / "goal.md").stat().st_size})
    return out


def read_transcript(cwd: Path, sid: str) -> dict:
    """Parse the Claude Code JSONL transcript for this sid."""
    jsonl = find_transcript_path(cwd, sid)
    if jsonl is None:
        guess = Path.home() / ".claude" / "projects" / encode_cwd_for_claude(cwd) / f"{sid}.jsonl"
        return {"exists": False, "path": str(guess), "events": []}
    events = []
    with jsonl.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = obj.get("timestamp") or obj.get("ts") or ""
            typ = obj.get("type", "")
            usage = None
            msg = obj.get("message") or {}
            if isinstance(msg, dict):
                usage = msg.get("usage")
            role = ""
            text_parts = []
            tool_name = None
            if typ == "user":
                role = "user"
                content = msg.get("content") if isinstance(msg, dict) else None
                if isinstance(content, str):
                    text_parts.append(content)
                elif isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict):
                            if c.get("type") == "text":
                                text_parts.append(c.get("text", ""))
                            elif c.get("type") == "tool_result":
                                role = "tool_result"
                                inner = c.get("content", "")
                                if isinstance(inner, list):
                                    for ic in inner:
                                        if isinstance(ic, dict) and ic.get("type") == "text":
                                            text_parts.append(ic.get("text", ""))
                                else:
                                    text_parts.append(str(inner))
            elif typ == "assistant":
                role = "assistant"
                content = msg.get("content") if isinstance(msg, dict) else None
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict):
                            if c.get("type") == "text":
                                text_parts.append(c.get("text", ""))
                            elif c.get("type") == "tool_use":
                                role = "tool_use"
                                tool_name = c.get("name")
                                inp = c.get("input")
                                text_parts.append(f"[{tool_name}] " + (json.dumps(inp, ensure_ascii=False) if inp else ""))
            elif typ in ("system", "summary"):
                role = "system"
                if isinstance(msg, dict):
                    text_parts.append(json.dumps(msg, ensure_ascii=False)[:2000])
                else:
                    text_parts.append(str(obj)[:2000])
            else:
                role = typ or "other"
            events.append({
                "ts": ts,
                "type": typ,
                "role": role,
                "tool": tool_name,
                "text": "\n".join(t for t in text_parts if t),
                "usage": usage,
            })
    return {"exists": True, "path": str(jsonl), "events": events}


def list_agents(cwd: Path, sid: str) -> list[dict]:
    """Extract subagent spawn records from the session JSONL.

    For each `tool_use` whose name is in {Task, Agent} we collect:
      - tool_use_id (correlation key)
      - input.description, input.prompt, input.subagent_type, input.model
      - timestamp
    We then walk the same JSONL for a matching `tool_result` (which carries
    `agentId` in its content) plus subsequent `task-notification` messages
    that reference the agentId — those mark completion.
    """
    jsonl = find_transcript_path(cwd, sid)
    if jsonl is None:
        return []
    spawns: dict[str, dict] = {}   # tool_use_id -> spawn dict
    completions: set[str] = set()  # tool_use_id known completed
    aid_for_tu: dict[str, str] = {}  # tool_use_id -> agentId
    try:
        with jsonl.open("r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                typ = obj.get("type", "")
                ts  = obj.get("timestamp") or obj.get("ts") or ""
                msg = obj.get("message") or {}
                # Skip sidechain events themselves — we want main's tool_use only.
                is_sidechain = bool(obj.get("isSidechain"))
                if typ == "assistant" and isinstance(msg, dict) and not is_sidechain:
                    content = msg.get("content")
                    if isinstance(content, list):
                        for c in content:
                            if not isinstance(c, dict):
                                continue
                            if c.get("type") != "tool_use":
                                continue
                            name = c.get("name") or ""
                            if name not in ("Task", "Agent"):
                                continue
                            tu_id = c.get("id") or ""
                            inp = c.get("input") or {}
                            if not isinstance(inp, dict):
                                inp = {}
                            spawns[tu_id] = {
                                "tool_use_id": tu_id,
                                "tool_name": name,
                                "description": inp.get("description") or "",
                                "prompt": inp.get("prompt") or "",
                                "subagent_type": inp.get("subagent_type") or "",
                                "model": inp.get("model") or "",
                                "started_at": ts,
                            }
                elif typ == "user" and isinstance(msg, dict):
                    # tool_result content carries agentId for our spawn correlation
                    content = msg.get("content")
                    if isinstance(content, list):
                        for c in content:
                            if not isinstance(c, dict):
                                continue
                            if c.get("type") != "tool_result":
                                continue
                            tu_id = c.get("tool_use_id") or ""
                            if tu_id not in spawns:
                                continue
                            # tool_result for a Task call typically signals completion
                            completions.add(tu_id)
                            # try to extract agentId from result text
                            inner = c.get("content")
                            text = ""
                            if isinstance(inner, list):
                                for ic in inner:
                                    if isinstance(ic, dict) and ic.get("type") == "text":
                                        text += ic.get("text", "")
                            elif isinstance(inner, str):
                                text = inner
                            m = re.search(r"agentId[\"'\s:=]+([A-Za-z0-9]{12,})", text)
                            if m:
                                aid_for_tu[tu_id] = m.group(1)
    except Exception:
        return []
    # Count sidechain message count per agentId (best effort)
    sidechain_counts: dict[str, int] = {}
    try:
        with jsonl.open("r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not obj.get("isSidechain"):
                    continue
                # agentId may live at top-level or inside message
                aid = obj.get("agentId") or ""
                if not aid:
                    msg = obj.get("message") or {}
                    if isinstance(msg, dict):
                        aid = msg.get("agentId") or ""
                if aid:
                    sidechain_counts[aid] = sidechain_counts.get(aid, 0) + 1
    except Exception:
        pass

    out = []
    for tu_id, s in spawns.items():
        aid = aid_for_tu.get(tu_id, "")
        short = aid[:8] if aid else tu_id[-8:]
        out.append({
            "agentId": aid,
            "short_aid": short,
            "tool_use_id": tu_id,
            "tool_name": s["tool_name"],
            "description": s["description"],
            "prompt": s["prompt"],
            "subagent_type": s["subagent_type"],
            "model": s["model"],
            "started_at": s["started_at"],
            "status": "completed" if tu_id in completions else "running",
            "sidechain_message_count": sidechain_counts.get(aid, 0) if aid else 0,
        })
    # newest first
    out.sort(key=lambda x: x.get("started_at") or "", reverse=True)
    return out


def _safe_join(root: Path, *parts: str) -> Path | None:
    p = (root.joinpath(*parts)).resolve()
    try:
        p.relative_to(root.resolve())
    except ValueError:
        return None
    return p


class Handler(BaseHTTPRequestHandler):
    server_version = "BarryViewer/2.7.2"

    def log_message(self, fmt, *args):
        sys.stderr.write("[viewer] " + (fmt % args) + "\n")

    # ----- helpers -----
    def _json(self, obj, code=200):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _text(self, text, code=200, ctype="text/plain; charset=utf-8"):
        data = text.encode("utf-8") if isinstance(text, str) else text
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _static(self, rel: str):
        p = _safe_join(VIEWER_DIR, rel.lstrip("/"))
        if p is None or not p.is_file():
            self._text("not found: " + rel, 404)
            return
        ctype = "text/plain; charset=utf-8"
        suf = p.suffix.lower()
        if suf == ".html": ctype = "text/html; charset=utf-8"
        elif suf == ".css": ctype = "text/css; charset=utf-8"
        elif suf == ".js":  ctype = "application/javascript; charset=utf-8"
        elif suf == ".json": ctype = "application/json; charset=utf-8"
        elif suf in (".png", ".jpg", ".jpeg", ".gif", ".svg"):
            ctype = f"image/{suf[1:]}"
        with p.open("rb") as f:
            data = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        # Static files: short cache so dev edits show up after refresh.
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(data)

    # ----- routing -----
    def do_GET(self):
        u = urlparse(self.path)
        qs = parse_qs(u.query)
        path = u.path
        cwd: Path = self.server.cwd  # type: ignore[attr-defined]

        if path == "/" or path == "/index.html":
            return self._static("index.html")
        if path.startswith("/api/"):
            return self._api(path, qs, cwd)
        if path.startswith("/lib/") or path.endswith(".css") or path.endswith(".js"):
            return self._static(path)
        # legacy data path support for transition
        return self._static(path)

    def _api(self, path: str, qs: dict, cwd: Path):
        try:
            if path == "/api/info":
                return self._json({
                    "cwd": str(cwd),
                    "cwd_exists": cwd.is_dir(),
                    "barry_dir": str(cwd / ".barry_workflow"),
                    "barry_exists": (cwd / ".barry_workflow").is_dir(),
                    "workspace_exists": (cwd / "workspace").is_dir(),
                    "claude_projects_dir": str(Path.home() / ".claude" / "projects" / encode_cwd_for_claude(cwd)),
                    "version": "2.7.2",
                })

            if path == "/api/sessions":
                return self._json({"sessions": list_sessions(cwd)})

            if path == "/api/workspace":
                return self._json(list_workspace(cwd))

            if path == "/api/session_files":
                sid = (qs.get("sid") or [""])[0]
                if not SAFE_NAME.match(sid):
                    return self._json({"error": "bad sid"}, 400)
                return self._json(list_session_files(cwd, sid))

            if path == "/api/file":
                sid = (qs.get("sid") or [""])[0]
                rel = (qs.get("path") or [""])[0]
                if not SAFE_NAME.match(sid) or not SAFE_NAME.match(rel):
                    return self._json({"error": "bad sid/path"}, 400)
                p = _safe_join(cwd / ".barry_workflow" / sid, rel)
                if p is None or not p.is_file():
                    return self._text("not found", 404)
                return self._text(p.read_text(encoding="utf-8", errors="replace"))

            if path == "/api/workspace_file":
                rel = (qs.get("path") or [""])[0]
                if not rel or not SAFE_REL.match(rel) or ".." in rel:
                    return self._json({"error": "bad path"}, 400)
                p = _safe_join(cwd / "workspace", rel)
                if p is None or not p.is_file():
                    return self._text("not found", 404)
                return self._text(p.read_text(encoding="utf-8", errors="replace"))

            if path == "/api/agents":
                sid = (qs.get("sid") or [""])[0]
                if not SAFE_NAME.match(sid):
                    return self._json({"error": "bad sid"}, 400)
                return self._json({"agents": list_agents(cwd, sid)})

            if path == "/api/transcript":
                sid = (qs.get("sid") or [""])[0]
                if not SAFE_NAME.match(sid):
                    return self._json({"error": "bad sid"}, 400)
                return self._json(read_transcript(cwd, sid))

            return self._json({"error": "unknown endpoint", "path": path}, 404)
        except Exception as e:
            import traceback
            traceback.print_exc()
            return self._json({"error": str(e)}, 500)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cwd", default=os.getcwd(),
                    help="project root (must contain .barry_workflow/ for live data)")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--host", default="127.0.0.1")
    args = ap.parse_args()

    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        print(f"[viewer] WARN: cwd does not exist: {cwd}", file=sys.stderr)

    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    srv.cwd = cwd  # type: ignore[attr-defined]
    host, port = srv.server_address[0], srv.server_address[1]
    print(f"[viewer] cwd     = {cwd}")
    print(f"[viewer] barry   = {cwd / '.barry_workflow'} (exists={(cwd / '.barry_workflow').is_dir()})")
    print(f"[viewer] listen  = http://{host}:{port}/")
    print(f"PORT= {port}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
