#!/bin/bash
set -e
cd "$(dirname "$0")"
PY=python3
[ -x .venv/bin/python ] && PY=.venv/bin/python
export TOHO_PROJECT_ROOT="$(pwd)"
export TOHO_MOVIE_MAKER_DATA="$(pwd)/東方ムービーメーカ"
export TOHO_CHAR_STUDIO_DATA="$(pwd)/東方キャラ立ち絵スタジオ"
[ -f app.py ] || { echo "app.py が見つかりません"; exit 1; }
"$PY" -c "from src.core.path_utils import ensure_app_layout; ensure_app_layout()" 2>/dev/null || true
[ -f psd_studio_app.py ] && { echo "起動: psd_studio_app.py"; "$PY" psd_studio_app.py &; }
echo "起動: app.py"; exec "$PY" app.py
