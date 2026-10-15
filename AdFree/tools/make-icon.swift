// Draws the AdFree app icon (a shield with a play button) at every size an .iconset needs.
// Usage: swift tools/make-icon.swift <output .iconset folder>   (make-icon.sh runs this for you)
import AppKit

func draw(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels)

    // macOS icon tile: artwork fills ~80% of the canvas with rounded corners.
    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(colors: [NSColor(srgbRed: 0.07, green: 0.10, blue: 0.17, alpha: 1),
                        NSColor(srgbRed: 0.04, green: 0.06, blue: 0.11, alpha: 1)])!.draw(in: tilePath, angle: -90)

    // Shield, drawn in a unit box centered in the tile.
    let box = tile.insetBy(dx: tile.width * 0.2, dy: tile.height * 0.16)
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: box.minX + x * box.width, y: box.minY + y * box.height) }
    let shield = NSBezierPath()
    shield.move(to: pt(0.5, 1.0))
    shield.curve(to: pt(0.0, 0.84), controlPoint1: pt(0.32, 0.96), controlPoint2: pt(0.14, 0.90))
    shield.line(to: pt(0.0, 0.50))
    shield.curve(to: pt(0.5, 0.0), controlPoint1: pt(0.0, 0.22), controlPoint2: pt(0.26, 0.08))
    shield.curve(to: pt(1.0, 0.50), controlPoint1: pt(0.74, 0.08), controlPoint2: pt(1.0, 0.22))
    shield.line(to: pt(1.0, 0.84))
    shield.curve(to: pt(0.5, 1.0), controlPoint1: pt(0.86, 0.90), controlPoint2: pt(0.68, 0.96))
    shield.close()
    NSGradient(colors: [NSColor(srgbRed: 0.45, green: 0.88, blue: 1.0, alpha: 1),
                        NSColor(srgbRed: 0.20, green: 0.62, blue: 0.95, alpha: 1)])!.draw(in: shield, angle: -90)

    // Play triangle.
    let play = NSBezierPath()
    play.move(to: pt(0.36, 0.70))
    play.line(to: pt(0.36, 0.30))
    play.line(to: pt(0.72, 0.50))
    play.close()
    NSColor(srgbRed: 0.04, green: 0.06, blue: 0.11, alpha: 1).setFill()
    play.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

guard CommandLine.arguments.count == 2 else {
    print("usage: make-icon.swift <output.iconset>")
    exit(1)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    let data = draw(pixels: px).representation(using: .png, properties: [:])!
    try data.write(to: out.appendingPathComponent("\(name).png"))
}
print("wrote \(sizes.count) images to \(out.path)")
