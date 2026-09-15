import Foundation
import Combine

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }
    var label: String { self == .celsius ? "°C" : "°F" }
}

/// User preferences, persisted to UserDefaults. Everything here is the "backbone" for
/// the Settings tab — some rows are wired into behavior already, others are placeholders.
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var openOnHover: Bool { didSet { defaults.set(openOnHover, forKey: "openOnHover") } }
    @Published var hoverHighlight: Bool { didSet { defaults.set(hoverHighlight, forKey: "hoverHighlight") } }
    @Published var swipeSensitivity: Double { didSet { defaults.set(swipeSensitivity, forKey: "swipeSensitivity") } }
    @Published var showTimerInPill: Bool { didSet { defaults.set(showTimerInPill, forKey: "showTimerInPill") } }
    @Published var accentFromArtwork: Bool { didSet { defaults.set(accentFromArtwork, forKey: "accentFromArtwork") } }
    @Published var temperatureUnit: TemperatureUnit { didSet { defaults.set(temperatureUnit.rawValue, forKey: "temperatureUnit") } }
    @Published var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: "focusMinutes") } }
    @Published var breakMinutes: Int { didSet { defaults.set(breakMinutes, forKey: "breakMinutes") } }
    @Published var enabledWidgets: Set<NotchTab> {
        didSet { defaults.set(enabledWidgets.map(\.rawValue).sorted(), forKey: "enabledWidgets") }
    }

    /// Swipe distance (points) needed to open/close. Sensitivity 0…1 maps to 80…20pt.
    var swipeThreshold: CGFloat { CGFloat(80 - swipeSensitivity * 60) }

    init() {
        openOnHover = defaults.object(forKey: "openOnHover") as? Bool ?? false
        hoverHighlight = defaults.object(forKey: "hoverHighlight") as? Bool ?? true
        swipeSensitivity = defaults.object(forKey: "swipeSensitivity") as? Double ?? 0.6
        showTimerInPill = defaults.object(forKey: "showTimerInPill") as? Bool ?? true
        accentFromArtwork = defaults.object(forKey: "accentFromArtwork") as? Bool ?? true
        temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: "temperatureUnit") ?? "") ?? .celsius
        focusMinutes = defaults.object(forKey: "focusMinutes") as? Int ?? 25
        breakMinutes = defaults.object(forKey: "breakMinutes") as? Int ?? 5
        if let stored = defaults.stringArray(forKey: "enabledWidgets") {
            var set = Set(stored.compactMap(NotchTab.init(rawValue:)))
            // A widget added in a later version isn't "disabled by the user", it just
            // didn't exist when these preferences were written — default it to on.
            let known = Set(defaults.stringArray(forKey: "knownWidgets") ?? [])
            for tab in NotchTab.widgets where !known.contains(tab.rawValue) {
                set.insert(tab)
            }
            enabledWidgets = set
        } else {
            enabledWidgets = Set(NotchTab.widgets)
        }
        defaults.set(NotchTab.widgets.map(\.rawValue), forKey: "knownWidgets")
    }
}
