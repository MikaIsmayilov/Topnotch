#!/bin/bash
# Builds and (re)launches the app, killing any previously running instance first.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT_DIR/scripts/build_app.sh" "${1:-debug}"

pkill -x Topnotch 2>/dev/null || true
sleep 0.3

open "$ROOT_DIR/build/Topnotch.app"
echo "==> Launched. Logs: log stream --predicate 'process == \"Topnotch\"' --level debug"
