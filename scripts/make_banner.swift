// Draws the README banner: assets/banner.png
//
// Echoes the app icon deliberately — a notch hanging from the top edge with the three
// equaliser bars inside — so the repo page and the Dock icon read as the same product.
//
// Usage: swift scripts/make_banner.swift <output-png-path>

import AppKit
import CoreGraphics

let W: CGFloat = 2400
let H: CGFloat = 760

let NOTCH_W: CGFloat = 620
let NOTCH_H: CGFloat = 150
let NOTCH_R: CGFloat = 74

let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func nsColor(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: space,
               colors: stops.map { rgb($0.0, $0.1) } as CFArray,
               locations: stops.map { $0.2 })!
}

/// Top edge flush, bottom corners rounded — the silhouette the app itself draws.
func notchPath() -> CGPath {
    let top = H
    let bottom = top - NOTCH_H
    let left = W / 2 - NOTCH_W / 2
    let right = W / 2 + NOTCH_W / 2
    let p = CGMutablePath()
    p.move(to: CGPoint(x: left, y: top))
    p.addLine(to: CGPoint(x: left, y: bottom + NOTCH_R))
    p.addArc(tangent1End: CGPoint(x: left, y: bottom),
             tangent2End: CGPoint(x: left + NOTCH_R, y: bottom), radius: NOTCH_R)
    p.addLine(to: CGPoint(x: right - NOTCH_R, y: bottom))
    p.addArc(tangent1End: CGPoint(x: right, y: bottom),
             tangent2End: CGPoint(x: right, y: top), radius: NOTCH_R)
    p.addLine(to: CGPoint(x: right, y: top))
    p.closeSubpath()
    return p
}

let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                    bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high

// Backdrop: graphite carrying a purple cast, matching the icon body.
ctx.drawLinearGradient(gradient([(0x2A2240, 1, 0.0), (0x171325, 1, 0.55), (0x0B0912, 1, 1.0)]),
                       start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Violet bloom spilling down from behind the notch.
ctx.drawRadialGradient(gradient([(0x8B5CF6, 0.38, 0.0), (0x7C4DFF, 0.12, 0.6), (0x7C4DFF, 0.0, 1.0)]),
                       startCenter: CGPoint(x: W / 2, y: H), startRadius: 0,
                       endCenter: CGPoint(x: W / 2, y: H), endRadius: 900, options: [])

// The notch.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 60, color: rgb(0x8B5CF6, 0.55))
ctx.addPath(notchPath())
ctx.setFillColor(rgb(0x08060D))
ctx.fillPath()
ctx.restoreGState()

// Equaliser bars inside the notch.
let barW: CGFloat = 62
let gap: CGFloat = 48
let heights: [CGFloat] = [58, 98, 76]
var barX = W / 2 - (barW * 3 + gap * 2) / 2
let baseline = H - NOTCH_H + 40

for h in heights {
    let r = CGRect(x: barX, y: baseline, width: barW, height: h)
    let bar = CGPath(roundedRect: r, cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 38, color: rgb(0xA78BFA, 0.9))
    ctx.addPath(bar)
    ctx.setFillColor(rgb(0x8B5CF6))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bar)
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0xD6BBFF, 1, 0.0), (0x8B5CF6, 1, 1.0)]),
                           start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.minY), options: [])
    ctx.restoreGState()
    barX += barW + gap
}

// Text.
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

func drawCentred(_ text: String, font: NSFont, color: NSColor, tracking: CGFloat, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: tracking,
    ]
    let s = NSAttributedString(string: text, attributes: attrs)
    let size = s.size()
    s.draw(at: NSPoint(x: (W - size.width) / 2, y: y))
}

drawCentred("Topnotch",
            font: .systemFont(ofSize: 168, weight: .bold),
            color: .white, tracking: -4, y: 250)

drawCentred("A dynamic notch companion for Apple silicon MacBooks",
            font: .systemFont(ofSize: 52, weight: .medium),
            color: nsColor(0xFFFFFF, 0.52), tracking: 0.5, y: 150)

NSGraphicsContext.restoreGraphicsState()

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: make_banner.swift <output-png>\n".data(using: .utf8)!)
    exit(1)
}
let out = CommandLine.arguments[1]
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL,
                                           "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("wrote \(out)")
