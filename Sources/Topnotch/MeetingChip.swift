import Foundation
import EventKit

/// A meeting condensed to what fits in the collapsed pill.
struct MeetingChip: Equatable {
    /// Identifies the occurrence, not the series, so dismissing today's standup doesn't
    /// silence tomorrow's.
    let id: String
    let title: String
    let minutesUntil: Int
    let hasJoinLink: Bool

    init(event: EKEvent) {
        id = CalendarManager.dismissKey(for: event)
        let raw = event.title ?? "Meeting"
        title = raw.count > 18 ? String(raw.prefix(17)) + "…" : raw
        minutesUntil = Int(ceil(event.startsAt.timeIntervalSinceNow / 60))
        hasJoinLink = CalendarManager.joinURL(for: event) != nil
    }

    var countdown: String {
        minutesUntil <= 0 ? "now" : "\(minutesUntil)m"
    }

    var pillText: String { "\(title) · \(countdown)" }

    /// In progress, or close enough that you should already be moving.
    var isUrgent: Bool { minutesUntil <= 2 }
}
