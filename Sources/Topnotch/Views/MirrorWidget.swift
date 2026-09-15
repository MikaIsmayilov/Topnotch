import SwiftUI

struct MirrorWidget: View {
    @ObservedObject var camera: CameraManager
    /// True only while this tab is showing *and* the notch is open, so the camera light
    /// is never on without something to look at.
    let isActive: Bool

    var body: some View {
        Group {
            switch camera.status {
            case .denied:
                EmptyStateView(
                    symbol: "video.slash",
                    title: "Camera access is off",
                    subtitle: "Enable it in System Settings → Privacy & Security"
                )
            case .unavailable:
                EmptyStateView(symbol: "video.slash", title: "No camera found")
            case .running, .idle:
                preview
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if isActive { camera.start() } }
        .onDisappear { camera.stop() }
        .onChange(of: isActive) { _, active in
            if active { camera.start() } else { camera.stop() }
        }
    }

    /// Kept as one view across idle/running rather than switching branches — swapping
    /// the view out and back in on every restart is what used to leave it blank.
    private var preview: some View {
        // A `.fill` aspect ratio deliberately overflows its frame, so the image has to
        // be pinned to measured bounds and clipped — otherwise it spills past the card
        // and out over the rest of the panel.
        GeometryReader { geo in
            ZStack {
                Theme.surface

                if let frame = camera.frame {
                    Image(decorative: frame, scale: 1, orientation: .up)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        // A mirror should match what you'd see in a real one, not the
                        // un-flipped image the sensor produces.
                        .scaleEffect(x: -1, y: 1)
                        .clipped()
                        .transition(.opacity)
                } else {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Starting camera…")
                            .font(.ui(12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.2), value: camera.frame == nil)
        }
    }
}
