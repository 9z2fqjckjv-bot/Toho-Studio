#!/bin/bash
cd "$(dirname "$0")/client" || exit 1
exec python3 ./renai_client.py "$@"
