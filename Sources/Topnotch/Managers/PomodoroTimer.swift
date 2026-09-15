import Foundation
import AppKit
import Combine

final class PomodoroTimer: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case focus = "Focus"
        case shortBreak = "Break"
        var id: String { rawValue }
    }

    @Published private(set) var mode: Mode = .focus
    @Published private(set) var secondsRemaining: Int
    @Published private(set) var isRunning = false
    @Published private(set) var completedFocusSessions = 0

    private let settings: SettingsStore
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: SettingsStore) {
        self.settings = settings
        secondsRemaining = settings.focusMinutes * 60

        // Changing a duration in Settings applies immediately unless a session is live.
        settings.$focusMinutes.merge(with: settings.$breakMinutes)
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isRunning else { return }
                self.secondsRemaining = self.duration(for: self.mode)
            }
            .store(in: &cancellables)
    }

    private func duration(for mode: Mode) -> Int {
        (mode == .focus ? settings.focusMinutes : settings.breakMinutes) * 60
    }

    var progress: Double {
        let total = duration(for: mode)
        guard total > 0 else { return 0 }
        return 1 - Double(secondsRemaining) / Double(total)
    }

    var formattedTime: String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        secondsRemaining = duration(for: mode)
    }

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        pause()
        mode = newMode
        secondsRemaining = duration(for: newMode)
    }

    private func tick() {
        guard secondsRemaining > 0 else {
            finishSession()
            return
        }
        secondsRemaining -= 1
    }

    private func finishSession() {
        if mode == .focus { completedFocusSessions += 1 }
        mode = (mode == .focus) ? .shortBreak : .focus
        secondsRemaining = duration(for: mode)
        NSSound(named: "Glass")?.play()
    }
}
