import SwiftUI
import EventKit

/// Month grid on the left, the selected day's agenda on the right.
struct CalendarWidget: View {
    @Environment(\.notchAccent) private var accent

    @ObservedObject var manager: CalendarManager

    @State private var displayedMonth = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current

    var body: some View {
        Group {
            if manager.authorizationDenied {
                EmptyStateView(
                    symbol: "calendar.badge.exclamationmark",
                    title: "Calendar access is off",
                    subtitle: "Enable it in System Settings → Privacy & Security"
                )
            } else {
                HStack(spacing: 10) {
                    monthCard
                        .frame(width: 226)
                    agendaCard
                }
            }
        }
        .onAppear { manager.reload(around: displayedMonth) }
    }

    // MARK: - Month

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text(monthTitle.uppercased())
                    .font(.ui(11, .semibold))
                    .tracking(0.9)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                monthArrow("chevron.left", offset: -1)
                monthArrow("chevron.right", offset: 1)
            }

            HStack(spacing: 3) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.ui(9, .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { column in
                            dayCell(for: gridDays[row * 7 + column])
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if !manager.accounts.isEmpty {
                Text(manager.accounts.joined(separator: " · "))
                    .font(.ui(9))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private func monthArrow(_ symbol: String, offset: Int) -> some View {
        Button {
            guard let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
            displayedMonth = next
            manager.reload(around: next)
        } label: {
            Image(systemName: symbol)
                .font(.ui(9, .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayCell(for day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let inMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)

        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            ZStack {
                if isSelected {
                    Circle().fill(Color.white.opacity(0.92))
                } else if isToday {
                    Circle().fill(Theme.surfaceRaised)
                }
                Text("\(calendar.component(.day, from: day))")
                    .font(.ui(11, isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? .black : (inMonth ? Theme.textPrimary : Theme.textTertiary)
                    )
            }
            .frame(height: 26)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                if manager.hasEvents(on: day) {
                    Circle()
                        .fill(isSelected ? Color.black.opacity(0.55) : accent)
                        .frame(width: 3, height: 3)
                        .offset(y: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Agenda

    private var agendaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(agendaTitle)
                    .font(.ui(12.5, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(Self.dayFormatter.string(from: selectedDay))
                    .font(.ui(10))
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
            }

            let dayEvents = manager.events(on: selectedDay)
            if dayEvents.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Theme.textTertiary)
                    Text("No events")
                        .font(.ui(11.5))
                        .foregroundStyle(Theme.textSecondary)
                    if !manager.hasGoogleAccount {
                        Button("Add an account…") { manager.openInternetAccountsSettings() }
                            .buttonStyle(.plain)
                            .font(.ui(10.5, .medium))
                            .foregroundStyle(accent)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(dayEvents, id: \.eventIdentifier) { event in
                            eventRow(event)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(event.calendar.cgColor))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled event")
                    .font(.ui(11.5, .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(timeLabel(for: event))
                    .font(.ui(10))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)

            if let join = CalendarManager.joinURL(for: event) {
                Button { NSWorkspace.shared.open(join) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill").font(.ui(8.5, .bold))
                        Text("Join").font(.ui(10, .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Capsule().fill(accent))
                }
                .buttonStyle(.plain)
                .help(join.absoluteString)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.surfaceRaised)
        )
    }

    // MARK: - Helpers

    private var gridDays: [Date] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let gridStart = calendar.dateInterval(of: .weekOfMonth, for: monthStart)?.start ?? monthStart
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(
            calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .year) ? "MMMM" : "MMMM yyyy"
        )
        return formatter.string(from: displayedMonth)
    }

    private var agendaTitle: String {
        if calendar.isDateInToday(selectedDay) { return "Today" }
        if calendar.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        if calendar.isDateInYesterday(selectedDay) { return "Yesterday" }
        return Self.weekdayFormatter.string(from: selectedDay)
    }

    private func timeLabel(for event: EKEvent) -> String {
        if event.isAllDay { return "All day" }
        let start = Self.timeFormatter.string(from: event.startsAt)
        guard event.endDate != nil else { return start }
        return "\(start) – \(Self.timeFormatter.string(from: event.endsAt))"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()
}
