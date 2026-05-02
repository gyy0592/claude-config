#!/bin/bash
# 启动纪委后台 daemon（手动调用）
# 用法: start-jw.sh [--project-dir <path>]
# 报告: /tmp/claude_jw/report.md
# 停止: stop-jw.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JW_DIR="/tmp/claude_jw"
PID_FILE="$JW_DIR/daemon.pid"
mkdir -p "$JW_DIR"

# 解析参数
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 已在运行则提示
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "纪委已在运行 (PID=$(cat "$PID_FILE"))"
    echo "  报告: $JW_DIR/report.md"
    echo "  停止: $(dirname "$0")/stop-jw.sh"
    exit 0
fi

DISCIPLINARY="$SCRIPT_DIR/disciplinary_check.sh"
if [ ! -x "$DISCIPLINARY" ]; then
    echo "ERROR: disciplinary_check.sh not found at $DISCIPLINARY" >&2
    exit 1
fi

# 重置时间戳使第一次立即执行
echo "0" > "$JW_DIR/last_check"

# 启动后台 daemon：每次审查后按判决结果 sleep（5 min 或 30 min）
nohup bash -c "
    while true; do
        CLAUDE_PROJECT_DIR='$PROJECT_DIR' bash '$DISCIPLINARY' --force
        INTERVAL=\$(cat '$JW_DIR/interval' 2>/dev/null || echo 300)
        sleep \"\$INTERVAL\"
    done
" >> "$JW_DIR/daemon.log" 2>&1 &

DAEMON_PID=$!
echo "$DAEMON_PID" > "$PID_FILE"
disown "$DAEMON_PID" 2>/dev/null || true

echo "纪委已启动 (PID=$DAEMON_PID, project=$PROJECT_DIR)"
echo "  报告: $JW_DIR/report.md"
echo "  日志: $JW_DIR/daemon.log"
echo "  停止: $(dirname "$0")/stop-jw.sh"
