# Topnotch

A dynamic notch app for the MacBook Pro. It draws a panel around the real camera cutout —
collapsed it's a slim pill that reacts to what's happening; swipe down and it opens into a
set of widgets.

<!-- Add a screenshot here -->

## Widgets

| | |
|---|---|
| **Music** | Now playing from Spotify or Apple Music — artwork, a scrubbable progress bar, transport controls, and an accent colour pulled from the album art. Click the art to jump to the player. |
| **Files** | A drop shelf. Drag files onto the notch to stash them, drag them back out anywhere. |
| **Notes** | A scratch pad that autosaves. |
| **Calendar** | Month grid plus the selected day's agenda, with a Join button for events that contain a video link. |
| **Timer** | Pomodoro with focus/break lengths and a cycle indicator. |
| **Weather** | Current conditions, a 12-hour forecast, and feels-like/humidity/wind. No API key needed (Open-Meteo). |
| **Mirror** | Live camera preview. |
| **Clipboard** | Recent copied text, capped at 50 entries. |

## The collapsed pill

It only grows as wide as it needs to be, and surfaces things without being opened:

- Album art and a live equalizer while music plays
- A running timer countdown
- A meeting starting within 15 minutes, with a countdown
- Battery on plug/unplug, and AirPods battery on connect

## Gestures

- **Two-finger swipe down** on the notch to open, **swipe up** to close
- **Swipe left/right** on the collapsed pill to change tracks
- Click also works; hover-to-open is off by default and can be enabled in Settings

## Requirements

- A MacBook Pro/Air with a notch. The cutout is measured from the display at runtime, so
  it adapts to whatever scaled resolution you run — notch width is a function of your
  display scaling, not your model. On a screen that reports no cutout (an external
  display, or a Mac without a notch) it falls back to a 200pt pill sized to that screen's
  own menu bar.
- macOS 14 or later

## Install

1. Download `Topnotch.dmg` from the [latest release](https://github.com/MikaIsmayilov/Topnotch/releases/latest).
2. Open it and drag **Topnotch** onto the **Applications** shortcut.
3. Eject the disk image and launch Topnotch from Applications.

Topnotch has no Dock icon or window — it lives in the notch. Look for the pill at the top
of your screen, and there's a menu bar item for quitting. Swipe down on the notch to open it.

**First launch needs one extra step.** The app is **ad-hoc signed**, not notarized, so
macOS will refuse to open it by double-click. Either right-click the app and choose
**Open**, then confirm — or run:

```sh
xattr -dr com.apple.quarantine /Applications/Topnotch.app
```

This is the tradeoff of not paying for an Apple Developer ID certificate. If you'd rather
not bypass Gatekeeper, build it yourself instead.

## Build from source

```sh
git clone https://github.com/MikaIsmayilov/Topnotch.git
cd Topnotch
./scripts/run.sh          # build, bundle, and launch
./scripts/release.sh      # build a distributable zip
./scripts/make_dmg.sh     # build the drag-to-Applications disk image
```

The app icon is drawn in code by `scripts/make_icon.swift`. `Resources/AppIcon.icns` is
committed, so you only need to regenerate it if you change the artwork:

```sh
./scripts/make_icon.sh    # re-render every size and recompile the .icns
```

`build_app.sh` signs with the first code-signing identity it finds in your keychain, and
falls back to ad-hoc. Signing with a stable identity matters during development: an
ad-hoc signature is derived from the code hash, so it changes on every build and macOS
re-asks for every permission each time.

## Permissions

Granted on first use, all optional — the relevant widget explains itself if you decline:

- **Calendar** for the calendar widget and meeting countdown
- **Location** for weather
- **Camera** for the mirror
- **Automation** (Spotify / Music) to read and control playback

## Notes and limitations

- Now playing works with **Spotify and Apple Music**. It reads them over AppleScript
  rather than the system-wide Now Playing API, because macOS restricts the private
  `MediaRemote` framework to Apple-signed processes — it returns nothing for third-party
  apps, including for Apple's own Music.app.
- Clipboard history is **text only**, held in memory, and cleared on quit. Entries marked
  concealed (what password managers set) are never recorded.
- There's no Focus/Do Not Disturb indicator. `INFocusStatusCenter` reports `false` on
  macOS 26 even when authorized with Focus sharing enabled, and the older
  `~/Library/DoNotDisturb` files no longer exist.
- The app icon is drawn full-bleed because macOS 26 composites a legacy `.icns` into its
  own rounded container — artwork carrying its own squircle ends up visibly nested inside
  a second one. The cost is that on macOS 14 and 15, which apply no mask, the icon reads
  with square corners.

## License

MIT — see [LICENSE](LICENSE).
