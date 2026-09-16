import SwiftUI
import AppKit

enum Theme {
    static let surface = Color.white.opacity(0.06)
    static let surfaceRaised = Color.white.opacity(0.10)
    static let hairline = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.32)
    static let defaultAccent = Color(red: 0.36, green: 0.86, blue: 0.56)
    static let focusAccent = Color(red: 0.36, green: 0.86, blue: 0.56)
    static let breakAccent = Color(red: 1.0, green: 0.62, blue: 0.30)

    static let railWidth: CGFloat = 60
    static let cardRadius: CGFloat = 12
}

extension Theme {
    /// The swatches offered in Settings. Stored as hex so the choice survives in
    /// UserDefaults and compares by identity — a round-tripped `Color` doesn't.
    /// The first is the original built-in green, so "default" is always reachable.
    static let accentPresets: [String] = [
        "5CDB8F", "4FA8FF", "7C82FF", "C07CFF", "FF6FAE", "FF6B5E", "FF9E4D", "F5D14E",
    ]
}

extension Color {
    /// Six-digit RGB hex, no alpha. Returns nil on anything malformed so a corrupted
    /// preference falls back to the built-in accent rather than rendering black.
    init?(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// The user's chosen accent, pushed down from the root so any widget can pick it up
/// without being handed the settings store. Falls back to the built-in green.
private struct NotchAccentKey: EnvironmentKey {
    static let defaultValue = Theme.defaultAccent
}

extension EnvironmentValues {
    var notchAccent: Color {
        get { self[NotchAccentKey.self] }
        set { self[NotchAccentKey.self] = newValue }
    }
}

extension Font {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func numeric(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func card(padding: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

extension NSImage {
    /// A vivid accent derived from the image's average color. Album art averages tend
    /// toward muddy browns, so saturation/brightness are floored to keep it lively.
    var accentColor: NSColor? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let data = ctx.data else { return nil }
        let p = data.bindMemory(to: UInt8.self, capacity: 4)
        let base = NSColor(
            red: CGFloat(p[0]) / 255, green: CGFloat(p[1]) / 255, blue: CGFloat(p[2]) / 255, alpha: 1
        ).usingColorSpace(.deviceRGB) ?? .white
        return NSColor(
            hue: base.hueComponent,
            saturation: max(base.saturationComponent, 0.55),
            brightness: max(base.brightnessComponent, 0.80),
            alpha: 1
        )
    }
}
