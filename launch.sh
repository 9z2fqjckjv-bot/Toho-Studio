#!/bin/sh
# Mac Terminal: start app.py and psd_studio_app.py
set -e
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$DIR/launch.py" "$@"
fi
exec python "$DIR/launch.py" "$@"
