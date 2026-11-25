#!/bin/bash
cd "$(dirname "$0")" || exit 1
exec nice -n 15 python3 ./stage_director_server.py "$@"
