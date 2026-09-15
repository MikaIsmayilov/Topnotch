import SwiftUI

/// Settings backbone. Rows marked "Soon" are placeholders for later; everything else is
/// live and persisted through `SettingsStore`.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var calendar: CalendarManager

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var launchAtLoginFailed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(title: "General") {
                    SettingsRow(title: "Open on hover", subtitle: "Expand when the cursor rests on the notch") {
                        Toggle("", isOn: $settings.openOnHover).settingsToggle()
                    }
                    SettingsRow(title: "Swipe sensitivity", subtitle: "How far a two-finger swipe has to travel") {
                        Slider(value: $settings.swipeSensitivity, in: 0...1)
                            .controlSize(.mini)
                            .tint(Theme.defaultAccent)
                            .frame(width: 110)
                    }
                    SettingsRow(
                        title: "Launch at login",
                        subtitle: launchAtLoginFailed ? "macOS refused — try moving the app to /Applications" : nil,
                        divider: false
                    ) {
                        Toggle("", isOn: Binding(
                            get: { launchAtLogin },
                            set: { wanted in
                                let ok = LoginItem.set(wanted)
                                launchAtLoginFailed = !ok
                                launchAtLogin = LoginItem.isEnabled
                            }
                        )).settingsToggle()
                    }
                }

                SettingsSection(title: "Notch") {
                    SettingsRow(title: "Show timer in pill", subtitle: "Countdown in the collapsed notch while running") {
                        Toggle("", isOn: $settings.showTimerInPill).settingsToggle()
                    }
                    SettingsRow(
                        title: "Accent from album art",
                        subtitle: "Tint the pill and player with the cover's colour",
                        divider: false
                    ) {
                        Toggle("", isOn: $settings.accentFromArtwork).settingsToggle()
                    }
                }

                SettingsSection(title: "Widgets") {
                    ForEach(Array(NotchTab.widgets.enumerated()), id: \.element) { index, tab in
                        SettingsRow(
                            title: tab.title,
                            symbol: tab.symbol,
                            divider: index < NotchTab.widgets.count - 1
                        ) {
                            Toggle("", isOn: widgetBinding(for: tab)).settingsToggle()
                        }
                    }
                }

                SettingsSection(title: "Calendar accounts") {
                    ForEach(Array(calendar.accounts.enumerated()), id: \.element) { index, name in
                        SettingsRow(
                            title: name,
                            symbol: name.localizedCaseInsensitiveContains("google") ? "g.circle.fill" : "calendar",
                            divider: true
                        ) {
                            Text("Synced")
                                .font(.ui(10.5))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    SettingsRow(
                        title: "Add an account",
                        subtitle: "Google, iCloud and Exchange sync through macOS",
                        divider: false
                    ) {
                        Button("Open") { calendar.openInternetAccountsSettings() }
                            .buttonStyle(.plain)
                            .font(.ui(11, .medium))
                            .foregroundStyle(Theme.defaultAccent)
                    }
                }

                SettingsSection(title: "Timer") {
                    SettingsRow(title: "Focus length") {
                        MinuteStepper(value: $settings.focusMinutes, range: 5...90, step: 5)
                    }
                    SettingsRow(title: "Break length", divider: false) {
                        MinuteStepper(value: $settings.breakMinutes, range: 1...30, step: 1)
                    }
                }

                SettingsSection(title: "About") {
                    SettingsRow(title: "Topnotch", subtitle: "Version 1.0 · built for the 14\" MacBook Pro notch", divider: false) {
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                            .buttonStyle(.plain)
                            .font(.ui(11, .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func widgetBinding(for tab: NotchTab) -> Binding<Bool> {
        Binding(
            get: { settings.enabledWidgets.contains(tab) },
            set: { enabled in
                if enabled {
                    settings.enabledWidgets.insert(tab)
                } else if settings.enabledWidgets.count > 1 {
                    settings.enabledWidgets.remove(tab)
                }
            }
        )
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.ui(9.5, .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 2)
            VStack(spacing: 0) { content }
                .card(padding: 0)
        }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var badge: String? = nil
    var divider: Bool = true
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.ui(12, .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.ui(12, .medium))
                            .foregroundStyle(badge == nil ? Theme.textPrimary : Theme.textSecondary)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.ui(8, .bold))
                                .tracking(0.5)
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.surfaceRaised))
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.ui(10.5))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 12)
                accessory
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if divider {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .padding(.leading, symbol == nil ? 12 : 40)
            }
        }
    }
}

private struct MinuteStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 6) {
            CircleIconButton(symbol: "minus", size: 22) {
                value = max(range.lowerBound, value - step)
            }
            .disabled(value <= range.lowerBound)
            .opacity(value <= range.lowerBound ? 0.4 : 1)

            Text("\(value) min")
                .font(.numeric(12, .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 48)

            CircleIconButton(symbol: "plus", size: 22) {
                value = min(range.upperBound, value + step)
            }
            .disabled(value >= range.upperBound)
            .opacity(value >= range.upperBound ? 0.4 : 1)
        }
    }
}

private extension Toggle {
    func settingsToggle() -> some View {
        self
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Theme.defaultAccent)
    }
}
