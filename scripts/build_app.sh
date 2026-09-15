#!/bin/bash
# Builds the Swift package and packages it into a real, ad-hoc-signed .app bundle
# so it behaves like a normal macOS app (Info.plist, TCC prompts, no Terminal window).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"
APP_NAME="Topnotch"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"

echo "==> Building ($CONFIG)"
cd "$ROOT_DIR"
if [ "$CONFIG" = "release" ]; then
    swift build -c release
    BIN_PATH=".build/release/Topnotch"
else
    swift build
    BIN_PATH=".build/debug/Topnotch"
fi

echo "==> Assembling app bundle at $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/Topnotch"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Regenerate with scripts/make_icon.sh if the artwork changes.
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "==> Warning: Resources/AppIcon.icns missing; run scripts/make_icon.sh"
fi

# A stable identity keeps TCC permissions (Calendar/Location/Camera) from resetting on
# every rebuild; fall back to ad-hoc if it hasn't been created yet.
# Prefer any real codesigning identity in the keychain (an Apple Development cert is
# ideal). Override with CODESIGN_IDENTITY=... if there's more than one.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F\" '/"/ {print $2; exit}')}"
if [ -n "$IDENTITY" ]; then
    echo "==> Signing as: $IDENTITY"
    codesign --force --sign "$IDENTITY" --timestamp=none "$APP_BUNDLE"
else
    echo "==> No signing identity found; using ad-hoc (permissions will reset each build)"
    codesign --force --sign - --timestamp=none "$APP_BUNDLE"
fi

echo "==> Done: $APP_BUNDLE"
