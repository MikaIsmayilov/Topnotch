#!/bin/bash
# Builds the drag-to-install disk image users expect from a Mac app.
#
# The app inside is ad-hoc signed (see release.sh) — a development certificate would only
# work on the machine that owns it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VOL="Topnotch"
APP="build/$VOL.app"
DMG="build/$VOL.dmg"
STAGE="build/dmg-stage"
TMP="build/tmp.dmg"

[ -d "$APP" ] || { echo "No $APP — run scripts/release.sh first"; exit 1; }

rm -rf "$STAGE" "$DMG" "$TMP"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
# The drop target: dragging onto this alias installs the app.
ln -s /Applications "$STAGE/Applications"

SIZE=$(( $(du -sm "$STAGE" | cut -f1) + 20 ))
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ \
    -format UDRW -size "${SIZE}m" "$TMP" >/dev/null

DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP" | grep '^/dev/' | head -1 | awk '{print $1}')
sleep 2

# Lay the window out so the app sits to the left of the Applications alias. Cosmetic —
# if Finder automation is unavailable the image still works, just unstyled.
osascript <<APPLESCRIPT || echo "    (skipped window layout)"
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 800, 500}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 110
    set text size of opts to 12
    set position of item "$VOL.app" of container window to {150, 190}
    set position of item "Applications" of container window to {450, 190}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

# Housekeeping folders the mount creates; they'd otherwise ship inside the image and
# show up for anyone with hidden files visible in Finder.
rm -rf "/Volumes/$VOL/.fseventsd" "/Volumes/$VOL/.Trashes" "/Volumes/$VOL/.TemporaryItems"
touch "/Volumes/$VOL/.metadata_never_index"

sync
hdiutil detach "$DEV" >/dev/null
hdiutil convert "$TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$TMP"
rm -rf "$STAGE"

echo "==> $DMG ($(du -h "$DMG" | cut -f1))"
