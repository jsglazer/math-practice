// makeicon.swift — render MathPractice's 1024×1024 base icon to a PNG.
//
//   swift Scripts/makeicon.swift [out.png]
//
// Draws into an offscreen bitmap (no window server required): a teal->blue
// rounded-rect tile with a white "f′" derivative glyph. Scaled into the
// AppIcon.appiconset by Scripts/make-icon.sh.
import AppKit
import Foundation

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let pixels = 1024
let S = CGFloat(pixels)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("could not allocate bitmap\n".utf8)); exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!

// Rounded-rect tile with a macOS-like inset + corner radius.
let inset = S * 0.085
let rect = NSRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let radius = rect.width * 0.2237
let tile = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

ctx.saveGraphicsState()
tile.addClip()
let top = NSColor(calibratedRed: 0.11, green: 0.64, blue: 0.60, alpha: 1)
let bottom = NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.82, alpha: 1)
NSGradient(starting: top, ending: bottom)!.draw(in: rect, angle: -90)
ctx.restoreGraphicsState()

// White "f′" glyph, centered, with a soft drop shadow for depth.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowOffset = NSSize(width: 0, height: -S * 0.012)
shadow.shadowBlurRadius = S * 0.03

let para = NSMutableParagraphStyle()
para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Georgia-Italic", size: S * 0.46) ?? NSFont.systemFont(ofSize: S * 0.46, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para,
    .shadow: shadow
]
let glyph = NSAttributedString(string: "f\u{2032}", attributes: attrs)
let size = glyph.size()
glyph.draw(in: NSRect(x: (S - size.width) / 2, y: (S - size.height) / 2 - S * 0.02,
                      width: size.width, height: size.height))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG encode failed\n".utf8)); exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath) (\(pixels)×\(pixels))")
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8)); exit(1)
}
