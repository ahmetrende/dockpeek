// Draws the DMG window background and writes Resources/DMGBackground.tiff.
// Run from the repo root: swift scripts/make-dmg-background.swift [preview.png]
// The window is 640 x 400 pt. scripts/make-dmg.sh puts the icon centers at (170, 180) and (470, 180),
// measured from the top left like Finder does. Core Graphics measures from the bottom left.
import CoreGraphics
import CoreText
import Foundation
import ImageIO

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let width = 640
let height = 400

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func draw(scale: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: width * scale, height: height * scale, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    context.setFillColor(color(0xF5F5F7))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // The arrow from DockPeek to Applications, at the height of the icon centers.
    let arrowY: CGFloat = 220
    context.setStrokeColor(color(0x0A84FF))
    context.setLineWidth(6)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 262, y: arrowY))
    context.addLine(to: CGPoint(x: 362, y: arrowY))
    context.strokePath()
    context.setFillColor(color(0x0A84FF))
    context.move(to: CGPoint(x: 382, y: arrowY))
    context.addLine(to: CGPoint(x: 358, y: arrowY + 16))
    context.addLine(to: CGPoint(x: 358, y: arrowY - 16))
    context.closePath()
    context.fillPath()

    // The instruction, below the icon names.
    let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, 17, nil)!
    let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color(0x3A3A3C)] as CFDictionary
    let text = CFAttributedStringCreate(nil, "Drag DockPeek to Applications" as CFString, attributes)!
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    context.textPosition = CGPoint(x: (CGFloat(width) - bounds.width) / 2 - bounds.minX, y: 70)
    CTLineDraw(line, context)

    return context.makeImage()!
}

// One TIFF with a 72 dpi and a 144 dpi image. Finder picks the one that fits the display.
let output = URL(fileURLWithPath: "Resources/DMGBackground.tiff")
let tiff = CGImageDestinationCreateWithURL(output as CFURL, "public.tiff" as CFString, 2, nil)!
for scale in [1, 2] {
    let properties = [
        kCGImagePropertyDPIWidth: 72 * scale,
        kCGImagePropertyDPIHeight: 72 * scale,
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 5],  // LZW
    ] as CFDictionary
    CGImageDestinationAddImage(tiff, draw(scale: scale), properties)
}
guard CGImageDestinationFinalize(tiff) else { fatalError("cannot write \(output.path)") }
print("Written: \(output.path)")

if CommandLine.arguments.count > 1 {
    let preview = URL(fileURLWithPath: CommandLine.arguments[1])
    let png = CGImageDestinationCreateWithURL(preview as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(png, draw(scale: 2), nil)
    guard CGImageDestinationFinalize(png) else { fatalError("cannot write \(preview.path)") }
}
