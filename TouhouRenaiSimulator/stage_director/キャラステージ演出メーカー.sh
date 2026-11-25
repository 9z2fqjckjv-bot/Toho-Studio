#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec nice -n 15 python3 "$DIR/stage_director_server.py" "$@"
