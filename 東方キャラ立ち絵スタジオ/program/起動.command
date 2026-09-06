#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"
export TOHO_PROJECT_ROOT="$ROOT"
export TOHO_CHAR_STUDIO_DATA="$ROOT/東方キャラ立ち絵スタジオ"
PY=python3
[ -x "$ROOT/.venv/bin/python" ] && PY="$ROOT/.venv/bin/python"
echo "🌸 東方キャラ立ち絵スタジオを起動しています..."
exec "$PY" "$ROOT/psd_studio_app.py" "$@"
