import SwiftUI

/// Ring on the left, session controls on the right: mode switch, one-tap duration
/// presets, pomodoro cycle progress, and transport.
struct TimerWidget: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: SettingsStore

    private var accent: Color {
        timer.mode == .focus ? Theme.focusAccent : Theme.breakAccent
    }

    private var presets: [Int] {
        timer.mode == .focus ? [15, 25, 45, 60] : [5, 10, 15]
    }

    private var currentLength: Int {
        timer.mode == .focus ? settings.focusMinutes : settings.breakMinutes
    }

    var body: some View {
        HStack(spacing: 10) {
            ringCard
                .frame(width: 196)
            controlsCard
        }
    }

    private var ringCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Theme.surfaceRaised, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: timer.progress)
                    .shadow(color: accent.opacity(0.45), radius: 7)

                VStack(spacing: 1) {
                    Text(timer.formattedTime)
                        .font(.numeric(34, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text(timer.isRunning ? timer.mode.rawValue.uppercased() : "PAUSED")
                        .font(.ui(8.5, .semibold))
                        .tracking(1.2)
                        .foregroundStyle(timer.isRunning ? accent : Theme.textTertiary)
                }
            }
            .frame(width: 150, height: 150)
        }
        .frame(maxHeight: .infinity)
        .padding(14)
        .cardSurface()
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            modePicker

            VStack(alignment: .leading, spacing: 6) {
                Text("LENGTH")
                    .font(.ui(8.5, .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.textTertiary)
                HStack(spacing: 5) {
                    ForEach(presets, id: \.self) { minutes in
                        presetChip(minutes)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("CYCLE")
                    .font(.ui(8.5, .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.textTertiary)
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < timer.completedFocusSessions % 4 ? Theme.focusAccent : Theme.surfaceRaised)
                            .frame(width: 8, height: 8)
                    }
                    Text("\(timer.completedFocusSessions) done")
                        .font(.ui(10))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 2)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button { timer.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.ui(12, .bold))
                        Text(timer.isRunning ? "Pause" : "Start")
                            .font(.ui(12.5, .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Capsule().fill(accent))
                }
                .buttonStyle(.plain)

                CircleIconButton(symbol: "arrow.counterclockwise", size: 34) { timer.reset() }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(PomodoroTimer.Mode.allCases) { mode in
                Button { timer.setMode(mode) } label: {
                    Text(mode.rawValue)
                        .font(.ui(11, .semibold))
                        .foregroundStyle(timer.mode == mode ? .black : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            Capsule().fill(timer.mode == mode ? Color.white.opacity(0.92) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.surfaceRaised))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: timer.mode)
    }

    private func presetChip(_ minutes: Int) -> some View {
        let isSelected = currentLength == minutes
        return Button {
            if timer.mode == .focus {
                settings.focusMinutes = minutes
            } else {
                settings.breakMinutes = minutes
            }
        } label: {
            Text("\(minutes)")
                .font(.numeric(11.5, .semibold))
                .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? accent : Theme.surfaceRaised)
                )
        }
        .buttonStyle(.plain)
        .help("\(minutes) minutes")
    }
}
