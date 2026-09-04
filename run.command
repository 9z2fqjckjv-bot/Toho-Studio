#!/bin/bash
# Finder でダブルクリックするとムービーメーカーを起動し、ターミナルを開いたままにする。
set -e
cd "$(dirname "$0")"

PY=python3
if [ -x .venv/bin/python ]; then
  PY=.venv/bin/python
fi

if [ ! -f app.py ]; then
  echo "app.py が見つかりません: $(pwd)" >&2
  read -r -p "キーを押すと閉じます..." _
  exit 1
fi

if [ -f psd_studio_app.py ]; then
  echo "起動: psd_studio_app.py"
  "$PY" psd_studio_app.py &
fi

echo "起動: app.py"
echo "終了するには Ctrl+C"
exec "$PY" app.py
