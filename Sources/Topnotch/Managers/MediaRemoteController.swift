import Foundation
import AppKit
import Combine

enum PlayerSource {
    case music
    case spotify

    var label: String { self == .music ? "Music" : "Spotify" }

    var bundleIdentifier: String {
        switch self {
        case .music: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }
}

struct NowPlayingInfo {
    var title: String
    var artist: String
    var album: String
    var artwork: NSImage?
    var accent: NSColor?
    var isPlaying: Bool
    var source: PlayerSource
    var position: Double?
    var duration: Double?
    var sampledAt: Date

    /// Interpolates playback position between polls so the progress bar moves smoothly.
    func estimatedPosition(at date: Date = Date()) -> Double? {
        guard let position else { return nil }
        guard isPlaying else { return position }
        let estimate = position + date.timeIntervalSince(sampledAt)
        if let duration { return min(estimate, duration) }
        return estimate
    }
}

/// Reads and controls Music.app / Spotify.app via AppleScript.
///
/// We originally tried the private MediaRemote framework (what Control Center's Now
/// Playing widget itself uses) via dlopen/dlsym, but as of recent macOS versions
/// `MRMediaRemoteGetNowPlayingInfo` returns nil for any process that isn't
/// Apple-signed with a private entitlement — confirmed empirically here even for
/// Apple's own Music.app. AppleScript is the reliable, fully public, App-Store-safe
/// fallback, at the cost of only covering these two named apps.
enum SkipDirection {
    case forward
    case backward
}

final class MediaRemoteController: ObservableObject {
    @Published private(set) var nowPlaying: NowPlayingInfo?
    /// Set briefly after a skip so the UI can show which way the track moved.
    @Published private(set) var lastSkip: SkipDirection?

    private var pollTimer: Timer?
    private let scriptQueue = DispatchQueue(label: "com.mike.topnotch.applescript")
    private var skipResetWork: DispatchWorkItem?
    private var artworkCacheKey: String?
    private var cachedArtwork: NSImage?
    private var cachedAccent: NSColor?

    private static let separator = "\u{1E}"

    init() {
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit { pollTimer?.invalidate() }

    func refresh() {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            let result = self.queryPlayingApp()
            DispatchQueue.main.async { self.nowPlaying = result }
        }
    }

    private func isRunning(bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    /// Prefers whichever app is actually playing; falls back to a paused track so the
    /// widget doesn't blank out between songs.
    private func queryPlayingApp() -> NowPlayingInfo? {
        let spotifyRunning = isRunning(bundleID: "com.spotify.client")
        let musicRunning = isRunning(bundleID: "com.apple.Music")
        let spotify = spotifyRunning ? query(source: .spotify) : nil
        if let spotify, spotify.isPlaying { return spotify }
        let music = musicRunning ? query(source: .music) : nil
        if let music, music.isPlaying { return music }
        return spotify ?? music
    }

    private func query(source: PlayerSource) -> NowPlayingInfo? {
        let rs = Self.separator
        let script = """
        tell application "\(source.label)"
            if player state is stopped then return "STOPPED"
            set t to current track
            return (name of t) & "\(rs)" & (artist of t) & "\(rs)" & (album of t) & "\(rs)" & (player state is playing) & "\(rs)" & (player position) & "\(rs)" & (duration of t)
        end tell
        """
        guard let result = runAppleScript(script), result != "STOPPED" else { return nil }
        let parts = result.components(separatedBy: rs)
        guard parts.count == 6 else { return nil }

        let key = "\(source)|\(parts[0])|\(parts[1])|\(parts[2])"
        if key != artworkCacheKey {
            let image = fetchArtwork(source: source)
            artworkCacheKey = key
            cachedArtwork = image
            cachedAccent = image?.accentColor
        }

        var duration = Self.parseNumber(parts[5])
        // Spotify reports duration in milliseconds; Music in seconds.
        if source == .spotify, let d = duration { duration = d / 1000 }

        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            artwork: cachedArtwork,
            accent: cachedAccent,
            isPlaying: parts[3] == "true",
            source: source,
            position: Self.parseNumber(parts[4]),
            duration: duration,
            sampledAt: Date()
        )
    }

    /// AppleScript renders numbers with the system decimal separator.
    private static func parseNumber(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func fetchArtwork(source: PlayerSource) -> NSImage? {
        switch source {
        case .music:
            let script = """
            tell application "Music"
                if (count of artworks of current track) is 0 then return
                return data of artwork 1 of current track
            end tell
            """
            guard let raw = runAppleScriptRawData(script) else { return nil }
            // Music artwork data via AppleScript sometimes carries a 4-byte header before
            // the actual image bytes — a long-standing quirk of this API.
            if let image = NSImage(data: raw) { return image }
            return NSImage(data: Data(raw.dropFirst(4)))
        case .spotify:
            let script = "tell application \"Spotify\" to return artwork url of current track"
            guard let urlString = runAppleScript(script), let url = URL(string: urlString),
                  let data = try? Data(contentsOf: url) else { return nil }
            return NSImage(data: data)
        }
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        return error == nil ? descriptor.stringValue : nil
    }

    private func runAppleScriptRawData(_ source: String) -> Data? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        guard error == nil, !descriptor.data.isEmpty else { return nil }
        return descriptor.data
    }

    private func send(_ command: String, to source: PlayerSource) {
        let script = "tell application \"\(source.label)\" to \(command)"
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript(script)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresh() }
        }
    }

    /// Both Music and Spotify expose `player position` in seconds (Spotify reports
    /// *duration* in milliseconds, but position in seconds — see `query`).
    func seek(to seconds: Double) {
        guard let info = nowPlaying else { return }
        let target = max(0, min(seconds, info.duration ?? seconds))
        // Reflect the new position immediately so the bar doesn't snap back to the old
        // one for the rest of the poll interval.
        applyLocalSeek(target)

        let script = "tell application \"\(info.source.label)\" to set player position to \(target)"
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript(script)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.refresh() }
        }
    }

    private func applyLocalSeek(_ seconds: Double) {
        guard var info = nowPlaying else { return }
        info.position = seconds
        info.sampledAt = Date()
        nowPlaying = info
    }

    /// Brings the app that's currently playing to the front, launching it if it isn't
    /// running.
    ///
    /// This deliberately uses `openApplication` rather than `NSRunningApplication
    /// .activate`: activate only makes the process frontmost, so an app whose window is
    /// minimized or closed stays out of sight. `openApplication` sends a reopen event —
    /// the same thing clicking the Dock icon does — which restores the window.
    func openPlayerApp() {
        let source = nowPlaying?.source ?? .spotify
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleIdentifier) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    func togglePlayPause() { send("playpause", to: nowPlaying?.source ?? .music) }

    func next() {
        flagSkip(.forward)
        send("next track", to: nowPlaying?.source ?? .music)
    }

    func previous() {
        flagSkip(.backward)
        send("previous track", to: nowPlaying?.source ?? .music)
    }

    private func flagSkip(_ direction: SkipDirection) {
        skipResetWork?.cancel()
        lastSkip = direction
        let work = DispatchWorkItem { [weak self] in self?.lastSkip = nil }
        skipResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }
}
