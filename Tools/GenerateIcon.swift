import AppKit
import Foundation

// Generate AppIcon.icns using AppKit only; no third-party build dependencies.

let fm = FileManager.default
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "./build")
let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

func wave(start: NSPoint, end: NSPoint, control1: NSPoint, control2: NSPoint, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: start)
    path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
    path.lineWidth = width
    path.lineCapStyle = .round
    path.stroke()
}

func drawIcon() {
    let background = NSBezierPath(
        roundedRect: NSRect(x: 88, y: 88, width: 848, height: 848),
        xRadius: 194,
        yRadius: 194
    )
    let shadow = NSShadow()
    shadow.shadowColor = color(26, 43, 69).withAlphaComponent(0.16)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -15)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    color(242, 245, 250).setFill()
    background.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(starting: .white, ending: color(233, 239, 248))!
    gradient.draw(in: background, angle: 90)
    color(43, 117, 243).setStroke()
    wave(start: NSPoint(x: 244, y: 686), end: NSPoint(x: 780, y: 686),
         control1: NSPoint(x: 392, y: 865), control2: NSPoint(x: 632, y: 865), width: 57)
    wave(start: NSPoint(x: 317, y: 612), end: NSPoint(x: 707, y: 612),
         control1: NSPoint(x: 420, y: 730), control2: NSPoint(x: 604, y: 730), width: 57)
    wave(start: NSPoint(x: 393, y: 536), end: NSPoint(x: 631, y: 536),
         control1: NSPoint(x: 460, y: 612), control2: NSPoint(x: 564, y: 612), width: 57)

    let speaker = NSBezierPath()
    speaker.move(to: NSPoint(x: 289, y: 417))
    speaker.line(to: NSPoint(x: 377, y: 417))
    speaker.line(to: NSPoint(x: 513, y: 515))
    speaker.curve(to: NSPoint(x: 526, y: 503),
                  controlPoint1: NSPoint(x: 519, y: 521),
                  controlPoint2: NSPoint(x: 526, y: 516))
    speaker.line(to: NSPoint(x: 526, y: 225))
    speaker.curve(to: NSPoint(x: 513, y: 213),
                  controlPoint1: NSPoint(x: 526, y: 213),
                  controlPoint2: NSPoint(x: 519, y: 207))
    speaker.line(to: NSPoint(x: 377, y: 300))
    speaker.line(to: NSPoint(x: 289, y: 300))
    speaker.close()
    color(25, 38, 61).setFill()
    speaker.fill()

    color(25, 38, 61).setStroke()
    wave(start: NSPoint(x: 579, y: 420), end: NSPoint(x: 579, y: 290),
         control1: NSPoint(x: 645, y: 398), control2: NSPoint(x: 645, y: 310), width: 42)
    wave(start: NSPoint(x: 645, y: 480), end: NSPoint(x: 645, y: 230),
         control1: NSPoint(x: 787, y: 420), control2: NSPoint(x: 787, y: 290), width: 42)
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in sizes {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: size, pixelsHigh: size,
                                       bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Cannot create icon bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    drawIcon()
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode icon")
    }
    try data.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", output.appendingPathComponent("AppIcon.icns").path, iconset.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
try fm.removeItem(at: iconset)
