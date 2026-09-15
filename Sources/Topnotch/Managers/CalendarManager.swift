import Foundation
import AppKit
import EventKit
import Combine

/// Reads events through EventKit, which transparently includes Google, iCloud, Exchange
/// and any other account added in System Settings → Internet Accounts. That's why there's
/// no Google API client here: a Google account synced by macOS shows up as an ordinary
/// EKSource, so linking one is an account-level action, not something this app implements.
final class CalendarManager: NSObject, ObservableObject {
    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var daysWithEvents: Set<Date> = []
    @Published private(set) var accounts: [String] = []
    @Published private(set) var authorizationDenied = false

    private let store = EKEventStore()
    private var lastLoadAnchor = Date()

    override init() {
        super.init()
        // Without this the app only notices new events when the Calendar tab is opened,
        // so a meeting added elsewhere would never reach the pill.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    @objc private func storeChanged() {
        reload(around: lastLoadAnchor)
    }

    func requestAccessIfNeeded() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            reload()
        case .notDetermined:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        self?.reload()
                    } else {
                        self?.authorizationDenied = true
                    }
                }
            }
        default:
            authorizationDenied = true
        }
    }

    /// Fetches enough to cover both the displayed month's grid and the upcoming list.
    func reload(around date: Date = Date()) {
        lastLoadAnchor = date
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        let gridStart = cal.dateInterval(of: .weekOfMonth, for: monthStart)?.start ?? monthStart
        let gridEnd = cal.date(byAdding: .day, value: 42, to: gridStart) ?? date
        let start = min(gridStart, cal.startOfDay(for: now))
        let end = max(gridEnd, cal.date(byAdding: .day, value: 35, to: now) ?? gridEnd)

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let fetched = store.events(matching: predicate)
            .filter { $0.startDate != nil }
            .sorted { $0.startsAt < $1.startsAt }
        let days = Set(fetched.map { cal.startOfDay(for: $0.startsAt) })
        let sourceTitles = store.sources
            .filter { !$0.calendars(for: .event).isEmpty }
            .map(\.title)
            .uniqued()

        DispatchQueue.main.async {
            self.events = fetched
            self.daysWithEvents = days
            self.accounts = sourceTitles
        }
    }

    func events(on day: Date) -> [EKEvent] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return events.filter { $0.startsAt < dayEnd && $0.endsAt > dayStart }
    }

    func hasEvents(on day: Date) -> Bool {
        daysWithEvents.contains(Calendar.current.startOfDay(for: day))
    }

    var upcoming: [EKEvent] {
        let now = Date()
        return events.filter { $0.endsAt >= now }
    }

    /// How far ahead a meeting counts as "imminent" and earns a spot in the pill.
    static let imminentWindow: TimeInterval = 15 * 60

    /// The next timed meeting starting within the window, or one already under way.
    /// All-day events are excluded — they aren't something you need to walk into.
    func imminentMeeting(now: Date = Date()) -> EKEvent? {
        events.first { event in
            guard !event.isAllDay else { return false }
            guard event.endsAt > now else { return false }
            return event.startsAt.timeIntervalSince(now) <= Self.imminentWindow
        }
    }

    /// Pulls a video-call link out of wherever the organiser happened to put it.
    static func joinURL(for event: EKEvent) -> URL? {
        if let url = event.url, isMeetingLink(url.absoluteString) { return url }
        for text in [event.location, event.notes].compactMap({ $0 }) {
            if let found = firstMeetingLink(in: text) { return found }
        }
        return nil
    }

    private static let meetingHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "chime.aws", "bluejeans.com", "gotomeeting.com",
    ]

    private static func isMeetingLink(_ string: String) -> Bool {
        meetingHosts.contains { string.localizedCaseInsensitiveContains($0) }
    }

    private static func firstMeetingLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url, isMeetingLink(url.absoluteString) else { continue }
            return url
        }
        return nil
    }

    /// Google calendars synced through macOS appear as a CalDAV source.
    var hasGoogleAccount: Bool {
        accounts.contains {
            $0.localizedCaseInsensitiveContains("google") || $0.localizedCaseInsensitiveContains("gmail")
        }
    }

    func openInternetAccountsSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!
        NSWorkspace.shared.open(url)
    }
}

/// EventKit hands back optional dates; an event without a start is meaningless here and
/// gets filtered out at fetch time, so these accessors stay simple at the call sites.
extension EKEvent {
    var startsAt: Date { startDate ?? .distantPast }
    var endsAt: Date { endDate ?? startDate ?? .distantPast }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
