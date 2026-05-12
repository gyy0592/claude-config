#!/usr/bin/env bash
# set_monitor_time.sh — Dynamic monitoring interval adjustment for military system
# Usage: bash set_monitor_time.sh <minutes>
# Modifies wording only; deployment still done by set_claude.sh / set_codex.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_MD="$SCRIPT_DIR/content/CLAUDE.md"
AGENTS_MD="$SCRIPT_DIR/content/AGENTS.md"
WORKFLOWS_MD="$SCRIPT_DIR/content/memory/workflows.md"

# Parameter validation
if [ $# -ne 1 ]; then
  echo "Usage: bash set_monitor_time.sh <minutes> (1-1440)" >&2
  exit 1
fi
NEW=$1
if ! [[ "$NEW" =~ ^[0-9]+$ ]] || [ "$NEW" -lt 1 ] || [ "$NEW" -gt 1440 ]; then
  echo "Error: minutes must be a positive integer between 1-1440, received \"$NEW\"" >&2
  exit 1
fi

# Detect current monitoring interval (extract N from first match of "每 N 分钟" in CLAUDE.md)
OLD=$(grep -oE '每 [0-9]+ 分钟' "$CLAUDE_MD" | head -1 | grep -oE '[0-9]+' || true)
if [ -z "$OLD" ]; then
  echo "Error: could not find '每 N 分钟' pattern in $CLAUDE_MD, unable to detect current interval." >&2
  exit 1
fi

if [ "$OLD" = "$NEW" ]; then
  echo "Already set to $OLD minutes, no change needed"
  exit 0
fi

# sed replacement across three target files
for f in "$CLAUDE_MD" "$AGENTS_MD" "$WORKFLOWS_MD"; do
  sed -i \
    -e "s|每 ${OLD} 分钟|每 ${NEW} 分钟|g" \
    -e "s|${OLD} 分钟监控一次|${NEW} 分钟监控一次|g" \
    -e "s|${OLD} 分钟回看|${NEW} 分钟回看|g" \
    -e "s|+ ${OLD} 分钟」|+ ${NEW} 分钟」|g" \
    "$f"
done

echo "Monitoring interval changed from ${OLD} minutes to ${NEW} minutes. Please run bash set_claude.sh && bash set_codex.sh to deploy to ~/.claude/ ~/.codex/."
