#!/bin/bash
# Renders the app icon from scripts/make_icon.swift and compiles it into Resources/AppIcon.icns.
# Only needs re-running when the icon artwork changes; the .icns is committed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT_DIR/build/AppIcon.iconset"
OUT="$ROOT_DIR/Resources/AppIcon.icns"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "==> Rendering icon variants"
swift "$ROOT_DIR/scripts/make_icon.swift" "$ICONSET"

echo "==> Compiling $OUT"
iconutil --convert icns "$ICONSET" --output "$OUT"
rm -rf "$ICONSET"

echo "==> Done: $OUT ($(du -h "$OUT" | cut -f1))"
