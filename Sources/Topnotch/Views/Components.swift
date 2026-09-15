import SwiftUI

struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.ui(13, .semibold))
                .foregroundStyle(Theme.textPrimary)
            if let detail {
                Text(detail)
                    .font(.ui(11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.ui(12.5, .medium))
                .foregroundStyle(Theme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.ui(11))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Small circular icon button used for secondary actions (reset, remove, etc).
struct CircleIconButton: View {
    let symbol: String
    var size: CGFloat = 32
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.ui(size * 0.4, .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(hovering ? Theme.surfaceRaised : Theme.surface))
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
