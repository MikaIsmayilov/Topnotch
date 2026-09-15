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
