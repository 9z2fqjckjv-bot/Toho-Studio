#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/client"
exec python3 ./renai_client.py "$@"
