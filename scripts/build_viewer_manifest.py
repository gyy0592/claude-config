#!/usr/bin/env python3
"""Build viewer/data/<sid>/manifest.json by scanning the session directory.

Usage:
    python3 scripts/build_viewer_manifest.py viewer/data/<sid>
"""
from __future__ import annotations
import json, re, sys
from pathlib import Path


def main(sess_dir: Path) -> None:
    sid = sess_dir.name
    files = sorted(p.name for p in sess_dir.iterdir() if p.is_file())

    reflections = sorted(f for f in files if f.startswith("reflection_") and f.endswith(".md"))
    agent_ledgers = sorted(f for f in files if f.startswith("action_agent_") and f.endswith(".md"))

    # Try to extract subagent ids from main action.md (look for `agent <id>` / `id=<id>`)
    sub_ids = set()
    action = sess_dir / "action.md"
    if action.exists():
        text = action.read_text(errors="replace")
        for m in re.finditer(r"agent[_ ]([A-Za-z0-9]{6,})", text):
            sub_ids.add(m.group(1))

    # Subagent entries: any agent_<aid>/ subdir + any action_agent_<name>.md ledger
    subagents = []
    for d in sorted(p for p in sess_dir.iterdir() if p.is_dir() and p.name.startswith("agent_")):
        aid = d.name[len("agent_"):]
        entry = {"aid": aid, "kind": "subdir"}
        if (d / "state.md").exists():
            entry["state_path"] = f"agent_{aid}/state.md"
        if (d / "action.md").exists():
            entry["action_path"] = f"agent_{aid}/action.md"
        subagents.append(entry)

    for lf in agent_ledgers:
        # action_agent_<name>.md → name
        m = re.match(r"action_agent_(.+)\.md$", lf)
        if not m:
            continue
        name = m.group(1)
        if any(s["aid"] == name for s in subagents):
            continue
        subagents.append({
            "aid": name,
            "kind": "ledger-only",
            "action_path": lf,
        })

    manifest = {
        "sid": sid,
        "main": {
            "state_path": "state.md" if (sess_dir / "state.md").exists() else None,
            "action_path": "action.md" if (sess_dir / "action.md").exists() else None,
            "transcript_path": "transcript.txt" if (sess_dir / "transcript.txt").exists() else None,
            "reflections": reflections,
        },
        "subagents": subagents,
        "files": files,
    }
    out = sess_dir / "manifest.json"
    out.write_text(json.dumps(manifest, indent=2))
    print(f"wrote {out}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    main(Path(sys.argv[1]))
