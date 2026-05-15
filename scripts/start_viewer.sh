#!/usr/bin/env bash
# start_viewer.sh — one-button local viewer launcher for Barry's Workflow sessions.
#
# Usage:
#   bash scripts/start_viewer.sh                    # auto-pick port, default sid (first one in data/index.json)
#   bash scripts/start_viewer.sh 9001               # explicit port
#   bash scripts/start_viewer.sh --sid <sid>        # specific session
#   bash scripts/start_viewer.sh stop               # kill any running viewer instance
#   bash scripts/start_viewer.sh status             # show if running + URL
#
# Notes:
# - Server runs in background, logs to /tmp/barry_viewer.log, PID in /tmp/barry_viewer.pid
# - URL is printed; if you SSH'd in, set up port forwarding before opening in browser:
#     ssh -L <port>:localhost:<port> user@host

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIEWER_DIR="$REPO_DIR/viewer"
PID_FILE="/tmp/barry_viewer.pid"
LOG_FILE="/tmp/barry_viewer.log"

if [ ! -d "$VIEWER_DIR" ]; then
    echo "[viewer] error: $VIEWER_DIR not found" >&2
    exit 1
fi

# ── subcommands ──────────────────────────────────────────
case "${1:-}" in
    stop)
        if [ -f "$PID_FILE" ]; then
            PID="$(cat "$PID_FILE")"
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null || true
                echo "[viewer] stopped pid=$PID"
            else
                echo "[viewer] stale pid file (pid=$PID not running)"
            fi
            rm -f "$PID_FILE"
        else
            echo "[viewer] not running"
        fi
        exit 0
        ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            PID="$(cat "$PID_FILE")"
            PORT="$(awk '/PORT=/{print $2}' "$LOG_FILE" 2>/dev/null | tail -1)"
            echo "[viewer] running pid=$PID port=${PORT:-?}"
            echo "         URL: http://localhost:${PORT:-?}/"
        else
            echo "[viewer] not running"
        fi
        exit 0
        ;;
esac

# ── auto-ingest sessions from $PWD/.barry_workflow/ (if present) ─
BARRY_DIR="$PWD/.barry_workflow"
if [ -d "$BARRY_DIR" ]; then
    # Find all <sid> subdirs containing state.md, sorted by state.md mtime (newest first)
    while IFS= read -r STATE_FILE; do
        SOURCE_DIR="$(dirname "$STATE_FILE")"
        INGEST_SID="$(basename "$SOURCE_DIR")"
        DEST_DIR="$VIEWER_DIR/data/$INGEST_SID"
        MANIFEST="$DEST_DIR/manifest.json"

        # Idempotence: skip if manifest is newer than both state.md and action.md
        SOURCE_ACTION="$SOURCE_DIR/action.md"
        SKIP=0
        if [ -f "$MANIFEST" ]; then
            NEWER=0
            [ "$MANIFEST" -nt "$STATE_FILE" ] && NEWER=1
            if [ -f "$SOURCE_ACTION" ]; then
                [ "$MANIFEST" -nt "$SOURCE_ACTION" ] || NEWER=0
            fi
            [ "$NEWER" -eq 1 ] && SKIP=1
        fi

        if [ "$SKIP" -eq 0 ]; then
            echo "[viewer] ingesting session $INGEST_SID ..."
            python3 "$REPO_DIR/scripts/build_viewer_manifest.py" \
                "$DEST_DIR" \
                --source "$SOURCE_DIR" \
                2>&1 | sed 's/^/[viewer]   /' || true
        else
            echo "[viewer] session $INGEST_SID up-to-date, skipping re-ingest"
        fi
    done < <(find "$BARRY_DIR" -mindepth 2 -maxdepth 2 -name "state.md" \
                 -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}')
fi

# ── stop any existing instance first (idempotent restart) ─
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    OLD_PID="$(cat "$PID_FILE")"
    kill "$OLD_PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    sleep 0.3
fi

# ── parse args ───────────────────────────────────────────
PORT=""
SID=""
while [ $# -gt 0 ]; do
    case "$1" in
        --sid) SID="$2"; shift 2 ;;
        --sid=*) SID="${1#--sid=}"; shift ;;
        [0-9]*) PORT="$1"; shift ;;
        *) echo "[viewer] unknown arg: $1" >&2; exit 2 ;;
    esac
done

# ── pick a free port if not given ────────────────────────
if [ -z "$PORT" ]; then
    PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')"
fi

# ── pick default sid if not given (first in data/index.json) ─
if [ -z "$SID" ]; then
    INDEX_FILE="$VIEWER_DIR/data/index.json"
    if [ -f "$INDEX_FILE" ]; then
        SID="$(python3 -c "import json; d=json.load(open('$INDEX_FILE')); s=(d.get('sessions') or d if isinstance(d, list) else d.get('sessions', [])); print((s[0].get('sid') if s and isinstance(s[0], dict) else (s[0] if s else '')) or '')" 2>/dev/null || true)"
    fi
fi

# ── launch ───────────────────────────────────────────────
cd "$VIEWER_DIR"
echo "PORT= $PORT" > "$LOG_FILE"
echo "SID = $SID" >> "$LOG_FILE"
nohup python3 -m http.server "$PORT" >> "$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$PID_FILE"

# ── verify it stayed up ──────────────────────────────────
sleep 0.5
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[viewer] FAILED to start. Last 5 lines of $LOG_FILE:" >&2
    tail -5 "$LOG_FILE" >&2
    rm -f "$PID_FILE"
    exit 1
fi

URL="http://localhost:${PORT}/"
[ -n "$SID" ] && URL="${URL}?sid=${SID}"

echo "[viewer] started pid=$SERVER_PID port=$PORT"
echo "[viewer] open in browser:"
echo ""
echo "    $URL"
echo ""
echo "[viewer] if SSH'd to this machine, set up port forwarding from your laptop:"
echo "    ssh -L ${PORT}:localhost:${PORT} $(whoami)@<this-host>"
echo ""
echo "[viewer] stop with:  bash scripts/start_viewer.sh stop"
echo "[viewer] logs:       $LOG_FILE"
