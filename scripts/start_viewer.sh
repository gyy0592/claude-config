#!/usr/bin/env bash
# start_viewer.sh — v2.7.1 launcher for Barry's Workflow session viewer.
#
# Usage:
#   bash scripts/start_viewer.sh                       # serve $PWD/.barry_workflow/
#   bash scripts/start_viewer.sh --cwd <path>          # serve <path>/.barry_workflow/
#   bash scripts/start_viewer.sh --port 9001 --cwd ~/proj
#   bash scripts/start_viewer.sh stop
#   bash scripts/start_viewer.sh status
#
# The server reads .barry_workflow/<sid>/ AND ~/.claude/projects/<encoded-cwd>/<sid>.jsonl
# live; no copy/ingest step required.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIEWER_DIR="$REPO_DIR/viewer"
SERVER_PY="$VIEWER_DIR/viewer_server.py"
PID_FILE="/tmp/barry_viewer.pid"
LOG_FILE="/tmp/barry_viewer.log"

if [ ! -f "$SERVER_PY" ]; then
    echo "[viewer] error: $SERVER_PY not found" >&2
    exit 1
fi

case "${1:-}" in
    stop)
        if [ -f "$PID_FILE" ]; then
            PID="$(cat "$PID_FILE")"
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null || true
                echo "[viewer] stopped pid=$PID"
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
            PORT="$(awk -F= '/^PORT=/{gsub(/ /,"",$2); print $2}' "$LOG_FILE" 2>/dev/null | tail -1)"
            echo "[viewer] running pid=$PID port=${PORT:-?}"
            echo "         URL: http://localhost:${PORT:-?}/"
        else
            echo "[viewer] not running"
        fi
        exit 0
        ;;
esac

CWD="$PWD"
PORT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --cwd) CWD="$2"; shift 2 ;;
        --cwd=*) CWD="${1#--cwd=}"; shift ;;
        --port) PORT="$2"; shift 2 ;;
        --port=*) PORT="${1#--port=}"; shift ;;
        [0-9]*) PORT="$1"; shift ;;
        *) echo "[viewer] unknown arg: $1" >&2; exit 2 ;;
    esac
done

# Expand ~ if user passed it literally.
CWD="$(eval echo "$CWD")"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    OLD_PID="$(cat "$PID_FILE")"
    kill "$OLD_PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    sleep 0.3
fi

if [ -z "$PORT" ]; then
    PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')"
fi

echo "PORT= $PORT" > "$LOG_FILE"
echo "CWD = $CWD" >> "$LOG_FILE"

nohup python3 "$SERVER_PY" --cwd "$CWD" --port "$PORT" >> "$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$PID_FILE"

sleep 0.5
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[viewer] FAILED to start. Last 10 lines of $LOG_FILE:" >&2
    tail -10 "$LOG_FILE" >&2
    rm -f "$PID_FILE"
    exit 1
fi

URL="http://localhost:${PORT}/"
echo "[viewer] started pid=$SERVER_PID port=$PORT cwd=$CWD"
echo "[viewer] open in browser:"
echo ""
echo "    $URL"
echo ""
echo "[viewer] if SSH'd in, port-forward from laptop:"
echo "    ssh -L ${PORT}:localhost:${PORT} $(whoami)@<this-host>"
echo ""
echo "[viewer] stop with:  bash scripts/start_viewer.sh stop"
echo "[viewer] logs:       $LOG_FILE"
