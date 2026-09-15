// Draws the Topnotch app icon and writes a full .iconset.
//
// The artwork is vector, so every size is rendered natively from the same geometry rather
// than downsampled from a single 1024 master. That keeps the 16pt and 32pt variants crisp,
// which is where a downsampled icon usually falls apart.
//
// Usage: swift scripts/make_icon.swift <output-iconset-dir>

import AppKit
import CoreGraphics

// Design canvas. All geometry below is expressed in these units and scaled at render time.
let S: CGFloat = 1024

// The artwork is drawn full-bleed rather than inset onto the classic 824pt icon grid.
// macOS 26 composites a legacy .icns into its own rounded container, so artwork that
// carries its own squircle ends up visibly nested inside a second one. Filling the canvas
// and letting the system mask do the shaping renders correctly. The trade-off is that on
// macOS 14/15, which apply no mask, the icon reads with square corners.
let BODY = CGRect(x: 0, y: 0, width: S, height: S)

let NOTCH_W: CGFloat = 562
let NOTCH_H: CGFloat = 251
let NOTCH_R: CGFloat = 112

let space = CGColorSpaceCreateDeviceRGB()

/// Top edge flush, bottom corners rounded — the same silhouette the app itself draws.
func notchPath() -> CGPath {
    let top = BODY.maxY
    let bottom = top - NOTCH_H
    let left = S / 2 - NOTCH_W / 2
    let right = S / 2 + NOTCH_W / 2
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

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func gradient(_ stops: [(UInt32, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: space,
               colors: stops.map { rgb($0.0) } as CFArray,
               locations: stops.map { $0.1 })!
}

/// Gradient whose stops carry alpha, so a bloom fades out instead of repainting the body.
func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: space,
               colors: stops.map { rgb($0.0, $0.1) } as CFArray,
               locations: stops.map { $0.2 })!
}

func render(size: CGFloat) -> CGImage {
    let px = Int(size)
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    // Shadow blur radii are in user space, so they scale with the CTM along with the geometry.
    ctx.scaleBy(x: size / S, y: size / S)

    // Graphite body carrying a purple cast.
    ctx.drawLinearGradient(gradient([(0x2E2542, 0.0), (0x1A1628, 0.5), (0x0B0912, 1.0)]),
                           start: CGPoint(x: 0, y: BODY.maxY),
                           end: CGPoint(x: 0, y: BODY.minY),
                           options: [])
    // Soft purple bloom behind the notch so the top half doesn't read flat.
    ctx.drawRadialGradient(gradient([(0x8B5CF6, 0.42, 0.0), (0x7C4DFF, 0.16, 0.55), (0x7C4DFF, 0.0, 1.0)]),
                           startCenter: CGPoint(x: S / 2, y: BODY.maxY), startRadius: 0,
                           endCenter: CGPoint(x: S / 2, y: BODY.maxY), endRadius: 534,
                           options: [])

    // The notch, glowing violet against the body.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 57, color: rgb(0x8B5CF6, 0.55))
    ctx.addPath(notchPath())
    ctx.setFillColor(rgb(0x08060D))
    ctx.fillPath()
    ctx.restoreGState()

    // Three equaliser bars, bottom-aligned inside the notch.
    let barW: CGFloat = 57
    let gap: CGFloat = 45
    let heights: [CGFloat] = [80, 139, 104]
    var x = S / 2 - (barW * 3 + gap * 2) / 2
    let baseline = BODY.maxY - NOTCH_H + 57

    for h in heights {
        let r = CGRect(x: x, y: baseline, width: barW, height: h)
        let bar = CGPath(roundedRect: r, cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 35, color: rgb(0xA78BFA, 0.9))
        ctx.addPath(bar)
        ctx.setFillColor(rgb(0x8B5CF6))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(bar)
        ctx.clip()
        ctx.drawLinearGradient(gradient([(0xD6BBFF, 0.0), (0x8B5CF6, 1.0)]),
                               start: CGPoint(x: 0, y: r.maxY),
                               end: CGPoint(x: 0, y: r.minY),
                               options: [])
        ctx.restoreGState()
        x += barW + gap
    }

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                               "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write("failed to write \(path)\n".data(using: .utf8)!)
        exit(1)
    }
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: make_icon.swift <output-iconset-dir>\n".data(using: .utf8)!)
    exit(1)
}
let outDir = CommandLine.arguments[1]

// (logical point size, @2x?) pairs required by iconutil.
let variants: [(CGFloat, Bool)] = [
    (16, false), (16, true),
    (32, false), (32, true),
    (128, false), (128, true),
    (256, false), (256, true),
    (512, false), (512, true),
]

for (pt, retina) in variants {
    let pixels = retina ? pt * 2 : pt
    let suffix = retina ? "@2x" : ""
    let name = "icon_\(Int(pt))x\(Int(pt))\(suffix).png"
    writePNG(render(size: pixels), to: "\(outDir)/\(name)")
}
print("wrote \(variants.count) variants to \(outDir)")
