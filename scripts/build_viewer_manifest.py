#!/usr/bin/env python3
"""Build viewer/data/<sid>/manifest.json by scanning the session directory.

Usage:
    python3 scripts/build_viewer_manifest.py <viewer-data-sid-dir> [--source <project-barry-workflow-sid-dir>]

If --source is given, the script will:
  1. Mirror state.md / action.md / transitions.log / reflection_*.md /
     nudge_counters.json from the source dir to the viewer data dir.
  2. Locate ~/.claude/projects/<encoded-cwd>/<sid>.jsonl (main session) and
     <sid>/subagents/agent-*.jsonl, and extract them via scripts/extract_transcript.py
     into the viewer data dir (transcript.txt + subagents/agent-<aid>.txt).
  3. Compute per-state durations from state.md stage_history.
  4. Bucket each JSONL turn's token usage by the FSM state active at its timestamp.

Encoded-cwd rule: every '/' and '_' in the project path becomes '-' (matches
Claude Code's project-dir encoding observed under ~/.claude/projects/).
"""
from __future__ import annotations
import json, re, sys, shutil, subprocess, os
from pathlib import Path
from datetime import datetime, timezone


# ──────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
EXTRACT = REPO_ROOT / "scripts" / "extract_transcript.py"


def encode_cwd(path: Path) -> str:
    # Claude Code maps '/' and '_' both to '-'.
    s = str(path)
    return re.sub(r"[/_]", "-", s)


def parse_iso(s: str):
    if not s:
        return None
    s = s.strip().strip('"').strip("'")
    # Tolerate trailing Z and missing colons; Python 3.11 fromisoformat handles Z.
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


def parse_state_yaml(text: str) -> dict:
    """Pull stage_history + created_at out of a state.md YAML block."""
    out = {"stage_history": [], "current_status": None, "created_at": None}
    m = re.search(r"---YAML---\n(.*?)\n---YAML---", text, re.S)
    body = m.group(1) if m else None
    if body is None:
        m2 = re.search(r"```yaml\n(.*?)```", text, re.S)
        body = m2.group(1) if m2 else ""
    cs = re.search(r"^current_status:\s*(\S+)", body, re.M)
    if cs:
        out["current_status"] = cs.group(1)
    ca = re.search(r"^created_at:\s*(\S+)", body, re.M)
    if ca:
        out["created_at"] = ca.group(1)
    sh = re.search(r"^stage_history:\s*\n((?:\s+-\s+.+\n?)*)", body, re.M)
    if sh:
        for line in sh.group(1).splitlines():
            mm = re.match(r"\s*-\s*\{(.+)\}\s*$", line)
            if not mm:
                continue
            o = {}
            for kv in mm.group(1).split(","):
                p = re.match(r'\s*(\w+):\s*"?([^",]+)"?\s*$', kv)
                if p:
                    o[p.group(1)] = p.group(2).strip()
            out["stage_history"].append(o)
    return out


def compute_state_durations(parsed_state: dict, last_ts_iso: str | None = None) -> list[dict]:
    """Walk stage_history chronologically and compute wall-clock per state.

    stage_history is recorded newest-first (most recent transition prepended).
    Reverse it, then duration_of(state_i) = at(transition_i+1) - at(transition_i).
    The initial state (BOOT) duration is between created_at and first transition.
    Last (current) state extends to last_ts_iso or now.
    """
    sh = list(reversed(parsed_state.get("stage_history", [])))
    if not sh:
        return []
    created = parse_iso(parsed_state.get("created_at") or "")
    out = []
    # If created_at present and first transition's source state is BOOT, account for BOOT duration.
    # We don't have "from" in entries — only "event" and "to". Inference: first transition's
    # "to" is the second state, which means before it we were in BOOT (or whatever first state is).
    if created is not None:
        t0 = parse_iso(sh[0].get("at", ""))
        if t0 is not None:
            out.append({
                "state": "BOOT",
                "from": parsed_state.get("created_at"),
                "to": sh[0].get("at"),
                "seconds": int((t0 - created).total_seconds()),
            })
    for i, entry in enumerate(sh):
        cur_state = entry.get("to")
        cur_t = parse_iso(entry.get("at", ""))
        if cur_t is None:
            continue
        if i + 1 < len(sh):
            nxt_t = parse_iso(sh[i + 1].get("at", ""))
        else:
            nxt_t = parse_iso(last_ts_iso) if last_ts_iso else None
        if nxt_t is None:
            continue
        out.append({
            "state": cur_state,
            "from": entry.get("at"),
            "to": sh[i + 1].get("at") if i + 1 < len(sh) else last_ts_iso,
            "seconds": max(0, int((nxt_t - cur_t).total_seconds())),
        })
    return out


def build_visit_spans(parsed_state: dict) -> list[dict]:
    """Return [{state, start, end (None if open)}] in chronological order, one row per visit."""
    sh = list(reversed(parsed_state.get("stage_history", [])))
    created = parse_iso(parsed_state.get("created_at") or "")
    spans = []
    if created is not None and sh:
        first_t = parse_iso(sh[0].get("at", ""))
        if first_t is not None:
            spans.append({"state": "BOOT", "start": created, "end": first_t})
    for i, entry in enumerate(sh):
        t = parse_iso(entry.get("at", ""))
        if t is None:
            continue
        t_end = parse_iso(sh[i + 1].get("at", "")) if i + 1 < len(sh) else None
        spans.append({"state": entry.get("to"), "start": t, "end": t_end})
    return spans


def bucket_by_visit(events: list[dict], spans: list[dict]) -> list[dict]:
    """One bucket per visit (not per state-name). Returns list aligned with spans."""
    buckets = [{
        "input_tokens": 0, "output_tokens": 0,
        "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0,
        "turns": 0,
    } for _ in spans]
    for ev in events:
        t = parse_iso(ev.get("ts") or "")
        if t is None:
            continue
        for i, sp in enumerate(spans):
            if sp["start"] is None:
                continue
            if t >= sp["start"] and (sp["end"] is None or t < sp["end"]):
                u = ev.get("usage") or {}
                b = buckets[i]
                b["input_tokens"]                += int(u.get("input_tokens") or 0)
                b["output_tokens"]               += int(u.get("output_tokens") or 0)
                b["cache_read_input_tokens"]     += int(u.get("cache_read_input_tokens") or 0)
                b["cache_creation_input_tokens"] += int(u.get("cache_creation_input_tokens") or 0)
                b["turns"]                       += 1
                break
    return buckets


def parse_jsonl_usage(jsonl_path: Path) -> list[dict]:
    """Yield {ts, usage} events from a session JSONL."""
    events = []
    if not jsonl_path.exists():
        return events
    with jsonl_path.open(errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = obj.get("message") or {}
            usage = msg.get("usage")
            if not usage:
                continue
            ts = obj.get("timestamp") or msg.get("timestamp")
            events.append({"ts": ts, "usage": usage})
    return events


def find_session_jsonl(project_cwd: Path, sid: str) -> Path | None:
    """Locate ~/.claude/projects/<encoded-cwd>/<sid>.jsonl."""
    enc = encode_cwd(project_cwd)
    candidate = Path.home() / ".claude" / "projects" / enc / f"{sid}.jsonl"
    if candidate.exists():
        return candidate
    # Fallback: scan ~/.claude/projects/*/<sid>.jsonl (encoding mismatch).
    for p in (Path.home() / ".claude" / "projects").glob(f"*/{sid}.jsonl"):
        return p
    return None


def find_subagent_jsonls(project_cwd: Path, sid: str) -> list[Path]:
    enc = encode_cwd(project_cwd)
    sub_dir = Path.home() / ".claude" / "projects" / enc / sid / "subagents"
    if sub_dir.is_dir():
        return sorted(sub_dir.glob("agent-*.jsonl"))
    # Fallback scan
    for p in (Path.home() / ".claude" / "projects").glob(f"*/{sid}/subagents"):
        return sorted(p.glob("agent-*.jsonl"))
    return []


def extract_transcript_to(jsonl: Path, out_path: Path) -> bool:
    """Subprocess scripts/extract_transcript.py jsonl → out_path."""
    if not EXTRACT.exists():
        return False
    try:
        r = subprocess.run(
            ["python3", str(EXTRACT), str(jsonl), "--tool-result-lines", "30"],
            capture_output=True, text=True, timeout=120,
        )
        if r.returncode != 0:
            print(f"[manifest] extract_transcript failed for {jsonl.name}: {r.stderr[:200]}", file=sys.stderr)
            return False
        out_path.write_text(r.stdout)
        return True
    except Exception as e:
        print(f"[manifest] extract_transcript error for {jsonl.name}: {e}", file=sys.stderr)
        return False


def mirror_source(source: Path, dest: Path) -> None:
    """Mirror session files into viewer/data/<sid>/.

    v2.4 F1: state.md / action.md become symlinks to the live source so the
    viewer (which polls every 5 s) sees fresh content without a re-ingest. If
    a pre-v2.4 snapshot (real file) is at the dest, it is removed first so
    upgrades happen on next start_viewer.sh run with no manual cleanup.
    """
    dest.mkdir(parents=True, exist_ok=True)
    LIVE = {"state.md", "action.md"}
    for name in ("state.md", "action.md", "transitions.log", "nudge_counters.json"):
        f = source / name
        if not f.exists():
            continue
        target = dest / name
        if name in LIVE:
            if target.is_symlink() or target.exists():
                try:
                    target.unlink()
                except OSError:
                    pass
            try:
                os.symlink(f.resolve(), target)
                continue
            except OSError:
                pass
        shutil.copy2(f, target)
    for f in source.glob("reflection_*.md"):
        shutil.copy2(f, dest / f.name)
    # Also any agent_<aid>/ subdirs the workflow may have produced.
    for d in source.iterdir():
        if d.is_dir() and d.name.startswith("agent_"):
            shutil.copytree(d, dest / d.name, dirs_exist_ok=True)


# ──────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────

def main() -> None:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("sess_dir", help="viewer/data/<sid>/ directory to write into")
    ap.add_argument("--source", help="optional <project>/.barry_workflow/<sid>/ to ingest from")
    args = ap.parse_args()

    sess_dir = Path(args.sess_dir).resolve()
    sess_dir.mkdir(parents=True, exist_ok=True)
    sid = sess_dir.name

    # 1. Optional ingest from source .barry_workflow/<sid>/
    project_cwd = None
    if args.source:
        source = Path(args.source).resolve()
        if not source.is_dir():
            print(f"[manifest] source {source} not a directory", file=sys.stderr)
            sys.exit(1)
        # source is expected to be <project>/.barry_workflow/<sid>/ — project_cwd is grandparent
        if source.parent.name == ".barry_workflow":
            project_cwd = source.parent.parent
        mirror_source(source, sess_dir)
        # Main jsonl + transcript
        if project_cwd is not None:
            main_jsonl = find_session_jsonl(project_cwd, sid)
            if main_jsonl is not None:
                extract_transcript_to(main_jsonl, sess_dir / "transcript.txt")
            else:
                print(f"[manifest] warn: main JSONL not found for sid={sid}", file=sys.stderr)
        # Subagents
        if project_cwd is not None:
            sub_jsonls = find_subagent_jsonls(project_cwd, sid)
            if sub_jsonls:
                sub_out = sess_dir / "subagents"
                sub_out.mkdir(exist_ok=True)
                for j in sub_jsonls:
                    aid = j.stem.replace("agent-", "")
                    extract_transcript_to(j, sub_out / f"agent-{aid}.txt")
                    # Also copy meta json if it exists.
                    meta = j.with_suffix(".meta.json")
                    if meta.exists():
                        shutil.copy2(meta, sub_out / f"agent-{aid}.meta.json")

    # 2. Scan viewer/data/<sid>/ for files (post-ingest if --source used).
    files = sorted(p.name for p in sess_dir.iterdir() if p.is_file())
    reflections = sorted(f for f in files if f.startswith("reflection_") and f.endswith(".md"))
    agent_ledgers = sorted(f for f in files if f.startswith("action_agent_") and f.endswith(".md"))

    # 3. Subagent entries
    subagents = []
    # 3a. Subagent transcripts ingested into subagents/
    sub_out = sess_dir / "subagents"
    if sub_out.is_dir():
        for txt in sorted(sub_out.glob("agent-*.txt")):
            aid = txt.stem.replace("agent-", "")
            entry = {
                "aid": aid,
                "kind": "jsonl-extract",
                "transcript_path": f"subagents/{txt.name}",
            }
            meta = txt.with_name(txt.stem + ".meta.json")
            if meta.exists():
                try:
                    mj = json.loads(meta.read_text())
                    entry["meta"] = {
                        k: mj.get(k) for k in ("description", "agent_type", "task_description")
                        if mj.get(k) is not None
                    }
                except Exception:
                    pass
            subagents.append(entry)
    # 3b. Legacy agent_<aid>/ subdirs (if any workflow puts state.md per subagent)
    for d in sorted(p for p in sess_dir.iterdir() if p.is_dir() and p.name.startswith("agent_")):
        aid = d.name[len("agent_"):]
        if any(s["aid"] == aid for s in subagents):
            continue
        entry = {"aid": aid, "kind": "subdir"}
        if (d / "state.md").exists():
            entry["state_path"] = f"agent_{aid}/state.md"
        if (d / "action.md").exists():
            entry["action_path"] = f"agent_{aid}/action.md"
        subagents.append(entry)
    # 3c. action_agent_<name>.md ledgers (no extracted transcript / subdir)
    for lf in agent_ledgers:
        m = re.match(r"action_agent_(.+)\.md$", lf)
        if not m:
            continue
        name = m.group(1)
        if any(s["aid"] == name for s in subagents):
            continue
        subagents.append({"aid": name, "kind": "ledger-only", "action_path": lf})

    # 4. Metrics: per-state durations + token usage buckets.
    metrics = {"per_state": []}
    state_md = sess_dir / "state.md"
    parsed = None
    if state_md.exists():
        parsed = parse_state_yaml(state_md.read_text(errors="replace"))
        spans = build_visit_spans(parsed)
        # Token bucketing: per visit (one bucket per span entry).
        events = []
        if project_cwd is not None:
            mj = find_session_jsonl(project_cwd, sid)
            if mj is not None:
                events = parse_jsonl_usage(mj)
        per_visit_tok = bucket_by_visit(events, spans) if events else [None] * len(spans)
        # One row per visit. Aggregation by state name happens in viewer.js.
        for sp, tok in zip(spans, per_visit_tok):
            if sp["start"] is None:
                continue
            secs = None
            if sp["end"] is not None:
                secs = max(0, int((sp["end"] - sp["start"]).total_seconds()))
            row = {
                "state": sp["state"],
                "from": sp["start"].isoformat().replace("+00:00", "Z"),
                "to": sp["end"].isoformat().replace("+00:00", "Z") if sp["end"] else None,
                "seconds": secs,
            }
            if tok:
                row.update({f"tok_{k}": v for k, v in tok.items()})
            metrics["per_state"].append(row)

    manifest = {
        "sid": sid,
        "main": {
            "state_path": "state.md" if (sess_dir / "state.md").exists() else None,
            "action_path": "action.md" if (sess_dir / "action.md").exists() else None,
            "transcript_path": "transcript.txt" if (sess_dir / "transcript.txt").exists() else None,
            "transitions_log_path": "transitions.log" if (sess_dir / "transitions.log").exists() else None,
            "reflections": reflections,
        },
        "subagents": subagents,
        "metrics": metrics,
        "current_status": parsed.get("current_status") if parsed else None,
        "files": files,
    }
    manifest_path = sess_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2))
    print(f"wrote {manifest_path}")

    # 5. Update viewer/data/index.json to include this sid (prepend if missing).
    index_path = REPO_ROOT / "viewer" / "data" / "index.json"
    if index_path.exists():
        try:
            index_data = json.loads(index_path.read_text())
        except Exception:
            index_data = {"sessions": []}
    else:
        index_data = {"sessions": []}

    sessions = index_data.get("sessions", [])
    # Check if sid already present (by sid field or bare string)
    already_present = any(
        (e.get("sid") if isinstance(e, dict) else e) == sid
        for e in sessions
    )
    if not already_present:
        # Build label from current_status + created_at for context
        label = sid
        if parsed is not None:
            cs = parsed.get("current_status") or ""
            ca = parsed.get("created_at") or ""
            if ca:
                try:
                    dt = datetime.fromisoformat(ca.replace("Z", "+00:00"))
                    date_str = dt.strftime("%Y-%m-%d")
                except Exception:
                    date_str = ca[:10]
                label = f"{cs} ({date_str})" if cs else date_str
        new_entry = {"sid": sid, "label": label}
        sessions.insert(0, new_entry)
        index_data["sessions"] = sessions
        # Atomic write via temp file
        tmp = index_path.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(index_data, indent=2))
        tmp.replace(index_path)
        print(f"updated {index_path} with sid={sid}")


if __name__ == "__main__":
    main()
