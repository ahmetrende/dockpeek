// Draws the DockPeek app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift [preview.png]
import CoreGraphics
import Foundation
import ImageIO

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func fill(_ context: CGContext, _ rect: CGRect, radius: CGFloat, _ fillColor: CGColor) {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(fillColor)
    context.fillPath()
}

/// One small window: a title bar with three dots and a few content lines.
func window(_ context: CGContext, _ rect: CGRect, body: UInt32, bar: UInt32, line: UInt32) {
    fill(context, rect, radius: 18, color(body))
    context.saveGState()
    context.clip(to: CGRect(x: rect.minX, y: rect.maxY - 40, width: rect.width, height: 40))
    fill(context, rect, radius: 18, color(bar))
    context.restoreGState()
    for (index, dot) in [UInt32(0xFF5F57), 0xFEBC2E, 0x28C840].enumerated() {
        context.setFillColor(color(dot))
        context.fillEllipse(in: CGRect(x: rect.minX + 18 + CGFloat(index) * 24, y: rect.maxY - 27, width: 14, height: 14))
    }
    for (index, width) in [CGFloat(0.75), 0.55, 0.68, 0.4].enumerated() {
        let y = rect.maxY - 80 - CGFloat(index) * 40
        fill(context, CGRect(x: rect.minX + 22, y: y, width: (rect.width - 44) * width, height: 16), radius: 8, color(line))
    }
}

func draw(size: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // The macOS icon grid puts an 824 pt tile in a 1024 pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    context.saveGState()
    context.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
    context.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x3A3A3C), color(0x1C1C1E)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // Panel and Dock together sit 50 pt below the center of the tile; this centers them.
    context.translateBy(x: 0, y: 50)

    // The preview panel and its pointer to the hovered icon.
    let panel = CGRect(x: 232, y: 380, width: 560, height: 360)
    fill(context, panel, radius: 40, color(0xFFFFFF, 0.14))
    context.setFillColor(color(0xFFFFFF, 0.14))
    context.move(to: CGPoint(x: 482, y: 380))
    context.addLine(to: CGPoint(x: 542, y: 380))
    context.addLine(to: CGPoint(x: 512, y: 345))
    context.closePath()
    context.fillPath()
    let first = CGRect(x: 262, y: 420, width: 230, height: 280)
    fill(context, first.insetBy(dx: -8, dy: -8), radius: 24, color(0x0A84FF))
    window(context, first, body: 0xF2F2F7, bar: 0xD1D1D6, line: 0xC7C7CC)
    window(context, CGRect(x: 532, y: 420, width: 230, height: 280), body: 0xAEAEB2, bar: 0x8E8E93, line: 0x8E8E93)

    // The Dock with three app icons. The middle one is hovered.
    fill(context, CGRect(x: 212, y: 180, width: 600, height: 120), radius: 44, color(0xFFFFFF, 0.16))
    for (index, hex) in [UInt32(0x0A84FF), 0x30D158, 0xFF9F0A].enumerated() {
        fill(context, CGRect(x: 322 + CGFloat(index) * 150, y: 205, width: 80, height: 80), radius: 20, color(hex))
    }
    context.setFillColor(color(0xFFFFFF, 0.9))
    context.fillEllipse(in: CGRect(x: 505, y: 186, width: 14, height: 14))

    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(url.path)") }
}

let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    writePNG(draw(size: points), to: iconset.appending(path: "icon_\(points)x\(points).png"))
    writePNG(draw(size: points * 2), to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Written: Resources/AppIcon.icns")

if CommandLine.arguments.count > 1 {
    writePNG(draw(size: 1024), to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
