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

- A MacBook Pro/Air with a notch (geometry is read from the display; falls back to the
  14" cutout if the screen doesn't report one)
- macOS 14 or later

## Install

Download the latest release, unzip, and move `Topnotch.app` to `/Applications`.

The app is **ad-hoc signed**, not notarized, so macOS will refuse to open it the first
time. Either right-click the app and choose **Open**, then confirm — or run:

```sh
xattr -dr com.apple.quarantine /Applications/Topnotch.app
```

This is the tradeoff of not paying for an Apple Developer ID certificate. If you'd rather
not bypass Gatekeeper, build it yourself instead.

## Build from source

```sh
git clone <this repo>
cd Notch
./scripts/run.sh          # build, bundle, and launch
./scripts/release.sh      # build a distributable zip
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

## License

MIT — see [LICENSE](LICENSE).
