#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"
export TOHO_PROJECT_ROOT="$ROOT"
export TOHO_MOVIE_MAKER_DATA="$ROOT/東方ムービーメーカ"
PY=python3
[ -x "$ROOT/.venv/bin/python" ] && PY="$ROOT/.venv/bin/python"
echo "🎬 東方ムービーメーカを起動しています..."
exec "$PY" "$ROOT/app.py" "$@"
