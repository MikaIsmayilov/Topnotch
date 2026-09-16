import SwiftUI

/// Laid out as separate modules — artwork, track/progress card, transport card — so the
/// panel reads as composed blocks rather than one flat pane, and the progress bar lives
/// at the bottom of its own card instead of hugging the artist name like an underline.
struct MusicWidget: View {
    @Environment(\.notchAccent) private var chosenAccent
    @ObservedObject var controller: MediaRemoteController
    var onOpenPlayer: () -> Void = {}

    @State private var artworkHovering = false
    @State private var badgeHovering = false

    private let artworkSize: CGFloat = 188

    /// Jumping to the player means you're done with the notch — get it out of the way.
    private func openPlayer() {
        controller.openPlayerApp()
        onOpenPlayer()
    }

    var body: some View {
        if let info = controller.nowPlaying {
            let accent = Color(nsColor: info.accent ?? NSColor(chosenAccent))
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { openPlayer() } label: {
                        artwork(info)
                            .frame(width: artworkSize, height: artworkSize)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.black.opacity(artworkHovering ? 0.42 : 0))
                                    .overlay {
                                        VStack(spacing: 6) {
                                            Image(systemName: "arrow.up.forward.app.fill")
                                                .font(.system(size: 24))
                                            Text("Open \(info.source.label)")
                                                .font(.ui(10.5, .semibold))
                                        }
                                        .foregroundStyle(.white)
                                        .opacity(artworkHovering ? 1 : 0)
                                    }
                            }
                            .overlay {
                                if let skip = controller.lastSkip {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.62))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: skip == .forward ? "forward.end.fill" : "backward.end.fill")
                                            .font(.system(size: 19, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.7)))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .onHover { artworkHovering = $0 }
                    .animation(.easeOut(duration: 0.15), value: artworkHovering)
                    .help("Open \(info.source.label)")

                    trackCard(info, accent: accent)
                }
                .frame(height: artworkSize)

                transportCard(info)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: controller.lastSkip)
            .animation(.easeOut(duration: 0.25), value: info.title)
        } else {
            EmptyStateView(
                symbol: "music.note",
                title: "Nothing playing",
                subtitle: "Play something in Music or Spotify"
            )
        }
    }

    private func artwork(_ info: NowPlayingInfo) -> some View {
        Group {
            if let image = info.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.surface)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(Theme.textTertiary)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private func trackCard(_ info: NowPlayingInfo, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { openPlayer() } label: {
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text(info.source.label.uppercased())
                        .font(.ui(9, .semibold))
                        .tracking(0.8)
                    Image(systemName: "arrow.up.forward")
                        .font(.ui(7, .bold))
                        .opacity(badgeHovering ? 1 : 0)
                }
                .foregroundStyle(badgeHovering ? Theme.textSecondary : Theme.textTertiary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { badgeHovering = $0 }
            .animation(.easeOut(duration: 0.15), value: badgeHovering)
            .help("Open \(info.source.label)")
            .padding(.bottom, 7)

            Text(info.title)
                .font(.ui(17, .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(info.artist)
                .font(.ui(12.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .padding(.top, 3)

            Spacer(minLength: 14)

            ProgressRow(info: info, accent: accent) { controller.seek(to: $0) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private func transportCard(_ info: NowPlayingInfo) -> some View {
        HStack(spacing: 30) {
            Button { controller.previous() } label: {
                Image(systemName: "backward.fill").font(.ui(17, .semibold))
            }
            Button { controller.togglePlayPause() } label: {
                ZStack {
                    Circle().fill(Color.white).frame(width: 46, height: 46)
                    Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                        .font(.ui(17, .bold))
                        .foregroundStyle(.black)
                        .offset(x: info.isPlaying ? 0 : 1.5)
                }
            }
            Button { controller.next() } label: {
                Image(systemName: "forward.fill").font(.ui(17, .semibold))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }
}

/// Draggable scrub bar. While a drag is in flight the local fraction wins over the
/// live playback position so the handle tracks the cursor instead of fighting it.
private struct ProgressRow: View {
    let info: NowPlayingInfo
    let accent: Color
    let onSeek: (Double) -> Void

    @State private var dragFraction: Double?
    @State private var hovering = false

    private var isScrubbing: Bool { dragFraction != nil }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = info.duration ?? 0
            let livePosition = info.estimatedPosition(at: context.date) ?? 0
            let liveFraction = duration > 0 ? min(max(livePosition / duration, 0), 1) : 0
            let fraction = dragFraction ?? liveFraction
            let shownPosition = dragFraction.map { $0 * duration } ?? livePosition

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.surfaceRaised)
                            .frame(height: isScrubbing || hovering ? 6 : 4)
                        Capsule()
                            .fill(accent)
                            .frame(width: geo.size.width * fraction, height: isScrubbing || hovering ? 6 : 4)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .offset(x: geo.size.width * fraction - 5)
                            .opacity(isScrubbing || hovering ? 1 : 0)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard duration > 0, geo.size.width > 0 else { return }
                                dragFraction = min(max(value.location.x / geo.size.width, 0), 1)
                            }
                            .onEnded { value in
                                guard duration > 0, geo.size.width > 0 else {
                                    dragFraction = nil
                                    return
                                }
                                let target = min(max(value.location.x / geo.size.width, 0), 1)
                                dragFraction = nil
                                onSeek(target * duration)
                            }
                    )
                    .onHover { hovering = $0 }
                    .animation(.easeOut(duration: 0.15), value: hovering)
                    .animation(.easeOut(duration: 0.15), value: isScrubbing)
                }
                .frame(height: 14)

                HStack {
                    Text(Self.format(shownPosition))
                    Spacer()
                    Text(duration > 0 ? "-" + Self.format(duration - shownPosition) : "--:--")
                }
                .font(.numeric(10))
                .monospacedDigit()
                .foregroundStyle(isScrubbing ? Theme.textSecondary : Theme.textTertiary)
            }
        }
        .frame(height: 34)
    }

    private static func format(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
