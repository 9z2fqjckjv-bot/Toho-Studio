#!/bin/bash
cd "$(dirname "$0")/stage_director" || exit 1
exec python3 ./stage_director_server.py "$@"
