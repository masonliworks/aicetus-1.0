#!/usr/bin/env bash
# start.sh — one-command launcher for the DSH remote bridge.
#
# Usage:
#   ./start.sh                    # default: dsh at http://127.0.0.1:3080, listen 0.0.0.0:3878
#   DSH_URL=http://127.0.0.1:3080 ./start.sh
#   ./start.sh --port 8080 --token mytoken
#
# Prints the LAN address + token to put into the iOS app.
set -euo pipefail
cd "$(dirname "$0")"

DSH_URL="${DSH_URL:-http://127.0.0.1:3080}"

echo "==> Checking dsh web at $DSH_URL ..."
if curl -s -m 3 -o /dev/null "$DSH_URL/"; then
  echo "    dsh web is reachable."
else
  echo "    WARNING: dsh web not reachable at $DSH_URL."
  echo "    Start it first, e.g.:  dsh web"
  echo "    (or point this bridge elsewhere with DSH_URL=...)"
fi

echo "==> Starting dsh-remote-bridge ..."
exec node server.js --dsh-url "$DSH_URL" "$@"
