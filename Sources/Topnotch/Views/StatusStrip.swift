import SwiftUI

/// The top strip: exactly notch-height, with the camera cutout dead-center left empty.
/// Content lives only in the two flanks. Reads its own width from a GeometryReader so the
/// flanks track the container continuously while it springs open/closed.
struct StatusStrip: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var media: MediaRemoteController
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: SettingsStore
    @ObservedObject var power: PowerMonitor

    private var accent: Color {
        guard settings.accentFromArtwork, let artworkAccent = media.nowPlaying?.accent else {
            return settings.accent
        }
        return Color(nsColor: artworkAccent)
    }

    /// Going back slides the opposite way; a natural track advance reads as forward.
    private var goingBackward: Bool { media.lastSkip == .backward }
    private var slideIn: Edge { goingBackward ? .leading : .trailing }
    private var slideOut: Edge { goingBackward ? .trailing : .leading }

    var body: some View {
        GeometryReader { geo in
            let flank = max(0, (geo.size.width - viewModel.notchWidth) / 2)
            let height = geo.size.height
            HStack(spacing: 0) {
                // Flank content is for the collapsed pill only — once expanded, the
                // panel below already shows all of this, so the strip stays clean.
                // Each flank is stacked over a Color.clear rather than being a bare
                // `if`: SwiftUI ignores .frame() on an EmptyView, so an empty flank
                // reserved no width at all and dragged the whole strip out of
                // alignment with the physical cutout.
                ZStack(alignment: .leading) {
                    Color.clear
                    if viewModel.isExpanded {
                        stripButton(tab: .clipboard, symbol: "doc.on.clipboard")
                            .padding(.leading, 12)
                    } else {
                        leftFlank(width: flank, height: height)
                    }
                }
                .frame(width: flank, height: height)
                .clipped()

                Color.clear
                    .frame(width: viewModel.notchWidth)

                ZStack(alignment: .trailing) {
                    Color.clear
                    if viewModel.isExpanded {
                        // The strip's flanks are dead space once expanded, so Settings
                        // lives up here instead of taking a slot in the widget rail.
                        settingsButton
                    } else {
                        rightFlank(width: flank, height: height)
                    }
                }
                .frame(width: flank, height: height)
                .clipped()
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: media.nowPlaying?.title)
        .animation(.easeOut(duration: 0.22), value: media.nowPlaying?.isPlaying)
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: media.lastSkip)
        .animation(.easeOut(duration: 0.22), value: timer.isRunning)
        .animation(.easeOut(duration: 0.18), value: viewModel.isDropTargeted)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: power.alert)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: viewModel.meetingChip)
    }

    private func alertSymbol(_ alert: PillAlert) -> String {
        switch alert {
        case .pluggedIn: return "bolt.fill"
        case .unplugged: return "battery.50"
        case .bluetooth: return "airpods.pro"
        }
    }

    private func alertTint(_ alert: PillAlert) -> Color {
        switch alert {
        case .pluggedIn: return settings.accent
        case .unplugged(let level): return level <= 20 ? .orange : Theme.textPrimary
        case .bluetooth: return Theme.textPrimary
        }
    }

    private var settingsButton: some View {
        stripButton(tab: .settings, symbol: "gearshape.fill")
            .padding(.trailing, 12)
    }

    /// Clipboard and Settings sit in the strip's flanks, which are otherwise dead space
    /// once the panel is open.
    private func stripButton(tab: NotchTab, symbol: String) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button { viewModel.select(tab) } label: {
            Image(systemName: symbol)
                .font(.ui(12, .medium))
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Theme.surfaceRaised : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    @ViewBuilder
    private func leftFlank(width: CGFloat, height: CGFloat) -> some View {
        if viewModel.isDropTargeted, width > 30 {
            Image(systemName: "arrow.down.doc.fill")
                .font(.ui(13, .semibold))
                .foregroundStyle(settings.accent)
                .padding(.leading, 12)
                .transition(.opacity)
        } else if let meeting = viewModel.meetingChip, width > 40 {
            // A meeting you're about to miss outranks album art for this space.
            HStack(spacing: 5) {
                Image(systemName: meeting.hasJoinLink ? "video.fill" : "calendar")
                    .font(.ui(10, .semibold))
                Text(meeting.pillText)
                    .font(.ui(10.5, .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(meeting.isUrgent ? Color.orange : Theme.textPrimary)
            .padding(.leading, 10)
            .transition(.opacity)
        } else if let info = media.nowPlaying, width > 32 {
            HStack(spacing: 8) {
                artwork(info, size: height - 12)
                    // Re-identified per track so a change animates, sliding the way the
                    // track moved rather than just cross-fading in place.
                    .id(info.title + info.artist)
                    .transition(.asymmetric(
                        insertion: .move(edge: slideIn).combined(with: .opacity),
                        removal: .move(edge: slideOut).combined(with: .opacity)
                    ))
                if width > 120 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(info.title)
                            .font(.ui(11, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(info.artist)
                            .font(.ui(9.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .lineLimit(1)
                    .transition(.opacity)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func rightFlank(width: CGFloat, height: CGFloat) -> some View {
        if viewModel.isDropTargeted, width > 30 {
            Text("Drop to add")
                .font(.ui(10, .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.trailing, 12)
                .transition(.opacity)
        } else if let alert = power.alert, width > 40 {
            HStack(spacing: 5) {
                Image(systemName: alertSymbol(alert))
                    .font(.ui(10, .semibold))
                Text(NotchViewModel.alertText(alert))
                    .font(.ui(10.5, .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(alertTint(alert))
            .padding(.trailing, 10)
            .transition(.opacity)
        } else if width > 40 {
            HStack(spacing: 5) {
                if timer.isRunning, settings.showTimerInPill {
                    Text(timer.formattedTime)
                        .font(.numeric(10, .semibold))
                        .monospacedDigit()
                        // Without these the countdown wraps onto a second line when the
                        // flank is tight, which looks broken in a notch-height strip.
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(timer.mode == .focus ? Theme.focusAccent : Theme.breakAccent)
                        .transition(.opacity)
                }
                // The skip indicator takes the equalizer's slot so the pill doesn't have
                // to change width just to acknowledge a swipe.
                if let skip = media.lastSkip {
                    Image(systemName: skip == .forward ? "forward.end.fill" : "backward.end.fill")
                        .font(.ui(11, .bold))
                        .foregroundStyle(accent)
                        .frame(width: 14)
                        .transition(.asymmetric(
                            insertion: .move(edge: skip == .forward ? .leading : .trailing)
                                .combined(with: .opacity),
                            removal: .opacity
                        ))
                } else if let info = media.nowPlaying, info.isPlaying {
                    AudioBars(color: accent)
                        .frame(width: 14, height: 11)
                        .transition(.opacity)
                }
            }
            .padding(.trailing, 10)
        }
    }

    @ViewBuilder
    private func artwork(_ info: NowPlayingInfo, size: CGFloat) -> some View {
        Group {
            if let image = info.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.surfaceRaised)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.ui(9, .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A tiny animated equalizer to indicate audio is playing, à la Control Center.
struct AudioBars: View {
    var color: Color = Theme.defaultAccent
    @State private var heights: [CGFloat] = [4, 7, 5]

    private let timer = Timer.publish(every: 0.22, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: heights[i])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: heights)
        .onReceive(timer) { _ in
            heights = (0..<3).map { _ in CGFloat.random(in: 3...11) }
        }
    }
}
