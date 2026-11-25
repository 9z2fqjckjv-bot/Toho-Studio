#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Minecraftサーバーやデスクトップ環境のCPU・ディスクI/Oを圧迫しないよう低優先度で実行
IONICE_BIN="$(command -v ionice || true)"
if [ -z "$IONICE_BIN" ] && [ -x /usr/bin/ionice ]; then IONICE_BIN="/usr/bin/ionice"; fi
if [ -z "$IONICE_BIN" ] && [ -x /usr/sbin/ionice ]; then IONICE_BIN="/usr/sbin/ionice"; fi

if [ -n "$IONICE_BIN" ]; then
  exec nice -n 15 "$IONICE_BIN" -c 3 "$SCRIPT_DIR/.venv/bin/python" "$SCRIPT_DIR/app.py" "${1:-8096}"
else
  exec nice -n 15 "$SCRIPT_DIR/.venv/bin/python" "$SCRIPT_DIR/app.py" "${1:-8096}"
fi
