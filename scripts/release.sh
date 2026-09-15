#!/bin/bash
# Builds a distributable zip.
#
# Deliberately ad-hoc signed, NOT signed with a development certificate: a development
# cert only works on the machine/team that owns it, so shipping one would produce an app
# nobody else can launch. Ad-hoc means Gatekeeper warns on first open and the user has to
# explicitly allow it (see README) — the only alternative is a paid Developer ID
# certificate plus notarization.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release
APP="build/Topnotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Topnotch "$APP/Contents/MacOS/Topnotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - --timestamp=none "$APP"

ZIP="build/Topnotch.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> $ZIP ($(du -h "$ZIP" | cut -f1))"
