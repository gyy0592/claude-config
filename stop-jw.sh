#!/bin/bash
# 停止纪委后台 daemon

JW_DIR="/tmp/claude_jw"
PID_FILE="$JW_DIR/daemon.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "纪委未运行"
    exit 0
fi

PID=$(cat "$PID_FILE")
# 先杀子进程（正在审查的 disciplinary_check.sh），再杀 daemon
pkill -P "$PID" 2>/dev/null || true
if kill "$PID" 2>/dev/null; then
    rm "$PID_FILE"
    echo "纪委已停止 (PID=$PID)"
else
    rm "$PID_FILE"
    echo "纪委已不在运行（进程不存在），已清理 PID 文件"
fi
