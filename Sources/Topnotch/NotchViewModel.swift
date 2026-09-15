import SwiftUI
import AppKit
import Combine

enum NotchTab: String, CaseIterable, Identifiable {
    case music, files, notes, calendar, timer, weather, mirror, clipboard, settings

    var id: String { rawValue }

    /// Lives in the notch strip rather than the rail.
    static let stripTabs: Set<NotchTab> = [.settings, .clipboard]

    /// Tabs that get a slot in the rail. Clipboard and Settings live in the strip
    /// instead, so they don't consume rail space.
    static var widgets: [NotchTab] { allCases.filter { $0 != .settings && $0 != .clipboard } }

    var symbol: String {
        switch self {
        case .music: return "music.note"
        case .files: return "tray.full.fill"
        case .notes: return "note.text"
        case .calendar: return "calendar"
        case .timer: return "timer"
        case .weather: return "cloud.sun.fill"
        case .mirror: return "person.fill.viewfinder"
        case .clipboard: return "doc.on.clipboard"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .music: return "Music"
        case .files: return "Files"
        case .notes: return "Notes"
        case .calendar: return "Calendar"
        case .timer: return "Timer"
        case .weather: return "Weather"
        case .mirror: return "Mirror"
        case .clipboard: return "Clipboard"
        case .settings: return "Settings"
        }
    }
}

/// Central state shared between the AppKit window controller and the SwiftUI content.
///
/// All geometry derives from the physical notch: the top strip is exactly notch-height
/// with the camera cutout dead-center, and content only ever lives in the flanks on
/// either side of it. The collapsed pill grows flanks only when it has something to
/// show, and shrinks to a slim rim around the notch when idle.
final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var selectedTab: NotchTab = .music
    @Published var isDropTargeted = false
    @Published private(set) var notchSize = CGSize(width: 200, height: 32)
    @Published private(set) var collapsedFlank: CGFloat = NotchViewModel.idleFlank

    /// Flanks are sized to whatever they actually have to show, so the pill never takes
    /// more width than its contents need. They stay symmetric because the panel is
    /// centered on the physical cutout.
    static let idleFlank: CGFloat = 16
    static let dropFlank: CGFloat = 70
    static let expandedFlank: CGFloat = 176
    static let bodyHeight: CGFloat = 316

    var notchWidth: CGFloat { notchSize.width }
    var stripHeight: CGFloat { notchSize.height }

    var collapsedSize: CGSize {
        CGSize(width: notchSize.width + 2 * collapsedFlank, height: stripHeight)
    }

    var expandedSize: CGSize {
        CGSize(width: notchSize.width + 2 * Self.expandedFlank, height: stripHeight + Self.bodyHeight)
    }

    let settings = SettingsStore()
    let mediaRemote = MediaRemoteController()
    let notesStore = NotesStore()
    let fileTray = FileTrayStore()
    let calendarManager = CalendarManager()
    let pomodoro: PomodoroTimer
    let weather = WeatherService()
    let camera = CameraManager()
    let power = PowerMonitor()
    let clipboard = ClipboardStore()

    /// A meeting close enough to matter, surfaced in the collapsed pill.
    @Published private(set) var meetingChip: MeetingChip?

    private var cancellables = Set<AnyCancellable>()
    private var tabResetWork: DispatchWorkItem?

    init() {
        pomodoro = PomodoroTimer(settings: settings)

        // Anything that changes what the flanks display has to re-measure them.
        // `secondsRemaining` matters because the countdown gets wider as it gains a
        // digit (9:59 → 10:00).
        let triggers: [AnyPublisher<Void, Never>] = [
            mediaRemote.$nowPlaying.map { _ in () }.eraseToAnyPublisher(),
            pomodoro.$isRunning.map { _ in () }.eraseToAnyPublisher(),
            pomodoro.$secondsRemaining.map { _ in () }.eraseToAnyPublisher(),
            settings.$showTimerInPill.map { _ in () }.eraseToAnyPublisher(),
            $isDropTargeted.map { _ in () }.eraseToAnyPublisher(),
            $notchSize.map { _ in () }.eraseToAnyPublisher(),
            power.$alert.map { _ in () }.eraseToAnyPublisher(),
            $meetingChip.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
            .sink { [weak self] in self?.recomputeFlank() }
            .store(in: &cancellables)

        // Re-evaluated on a timer as well as on calendar changes, since "starts in 8m"
        // goes stale on its own without anything else happening.
        Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .map { _ in () }
            .merge(with: calendarManager.$events.map { _ in () })
            .sink { [weak self] in self?.refreshMeetingChip() }
            .store(in: &cancellables)

        settings.$enabledWidgets
            .sink { [weak self] enabled in
                guard let self, !NotchTab.stripTabs.contains(self.selectedTab),
                      !enabled.contains(self.selectedTab) else { return }
                self.selectedTab = NotchTab.widgets.first(where: enabled.contains) ?? .settings
            }
            .store(in: &cancellables)
    }

    /// Measures what the flanks actually need rather than assuming a fixed width. The
    /// flank frame is trailing-aligned and clipped, so anything wider than it gets cut
    /// off right at the camera cutout — which ate the leading digit of the countdown.
    private func recomputeFlank() {
        let flank: CGFloat

        if isDropTargeted {
            flank = Self.dropFlank
        } else {
            let info = mediaRemote.nowPlaying
            let barsVisible = info?.isPlaying == true
            let timerVisible = pomodoro.isRunning && settings.showTimerInPill

            var right: CGFloat = 0
            if let alert = power.alert {
                // A transient alert takes the whole right flank for itself.
                right = Self.glyphWidth + Self.contentSpacing + Self.width(of: Self.alertText(alert), font: Self.chipFont)
            } else {
                var parts: [CGFloat] = []
                if timerVisible { parts.append(Self.width(of: pomodoro.formattedTime, font: Self.timerFont)) }
                if barsVisible { parts.append(Self.barsWidth) }
                right = parts.reduce(0, +) + CGFloat(max(0, parts.count - 1)) * Self.contentSpacing
            }
            if right > 0 { right += Self.edgePadding + Self.cutoutMargin }

            var left: CGFloat = 0
            if let meeting = meetingChip {
                left = Self.glyphWidth + Self.contentSpacing
                    + Self.width(of: meeting.pillText, font: Self.chipFont)
                    + Self.edgePadding + Self.cutoutMargin
            } else if info != nil {
                left = Self.edgePadding + max(0, stripHeight - 12) + Self.cutoutMargin
            }

            flank = max(Self.idleFlank, left, right)
        }

        guard abs(flank - collapsedFlank) > 0.5 else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            collapsedFlank = flank
        }
    }

    private static let barsWidth: CGFloat = 14
    private static let contentSpacing: CGFloat = 5
    private static let edgePadding: CGFloat = 10
    /// Keeps flank content from butting up against the camera cutout.
    private static let cutoutMargin: CGFloat = 8

    private static let glyphWidth: CGFloat = 13
    private static let timerFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    private static let chipFont = NSFont.systemFont(ofSize: 10.5, weight: .medium)

    private static func width(of text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    static func alertText(_ alert: PillAlert) -> String {
        switch alert {
        case .pluggedIn(let level): return "\(level)%"
        case .unplugged(let level): return "\(level)%"
        case .bluetooth(let name, let level):
            // Device names run long ("Mika's AirPods Pro") and the pill is narrow.
            let short = name.count > 16 ? String(name.prefix(15)) + "\u{2026}" : name
            return "\(short) \(level)%"
        }
    }

    private func refreshMeetingChip() {
        let chip = calendarManager.imminentMeeting().map(MeetingChip.init(event:))
        guard chip != meetingChip else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            meetingChip = chip
        }
    }

    var visibleTabs: [NotchTab] {
        NotchTab.widgets.filter { settings.enabledWidgets.contains($0) }
    }

    func configure(notchSize: CGSize) {
        self.notchSize = notchSize
    }

    func expand(to tab: NotchTab? = nil) {
        tabResetWork?.cancel()
        if let tab {
            selectedTab = tab
        }
        // Overshooting bigger than the target while opening reads as a satisfying
        // bounce. Overshooting *smaller* while closing would shrink past the pill and
        // flash the real camera cutout, so that direction is critically damped.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
            isExpanded = true
        }
    }

    func collapse() {
        withAnimation(.spring(response: 0.42, dampingFraction: 1.0)) {
            isExpanded = false
        }

        // Reopening always lands on the player rather than wherever you happened to
        // leave off. Deferred past the close animation so the swap isn't visible, and
        // skipped if you reopen before it fires.
        tabResetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isExpanded else { return }
            self.selectedTab = self.settings.enabledWidgets.contains(.music)
                ? .music
                : (self.visibleTabs.first ?? .settings)
        }
        tabResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }

    func select(_ tab: NotchTab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selectedTab = tab
        }
    }
}
