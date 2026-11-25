#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/stage_director"
exec python3 ./stage_director_server.py "$@"
