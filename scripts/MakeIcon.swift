import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: make-icon WindowPin.icns\n", stderr)
    exit(1)
}

let destination = URL(fileURLWithPath: arguments[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("WindowPin.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
do {
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    try writeIconSet(to: iconset)
    try runIconutil(iconset: iconset, destination: destination)
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
try? FileManager.default.removeItem(at: iconset)

func writeIconSet(to iconset: URL) throws {

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in sizes {
    let image = drawIcon(pixels: pixels)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("could not encode \(name)\n", stderr)
        exit(1)
    }
        try png.write(to: iconset.appendingPathComponent(name))
    }
}

func runIconutil(iconset: URL, destination: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw NSError(domain: "MakeIcon", code: Int(process.terminationStatus))
    }
}

func drawIcon(pixels: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    let inset = rect.insetBy(dx: pixels * 0.04, dy: pixels * 0.04)
    let path = NSBezierPath(roundedRect: inset, xRadius: pixels * 0.22, yRadius: pixels * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.29, green: 0.56, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.12, green: 0.33, blue: 0.86, alpha: 1),
    ])
    gradient?.draw(in: path, angle: -90)
    NSColor.white.withAlphaComponent(0.22).setStroke()
    path.lineWidth = max(1, pixels * 0.015)
    path.stroke()

    let symbolSize = pixels * 0.52
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize * 0.78, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        let symbolRect = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: symbolRect)
        NSGraphicsContext.current?.compositingOperation = .sourceAtop
        NSColor.white.setFill()
        symbolRect.fill()
        tinted.unlockFocus()
        tinted.isTemplate = false
        let origin = NSPoint(x: (pixels - tinted.size.width) / 2, y: (pixels - tinted.size.height) / 2 - pixels * 0.02)
        tinted.draw(at: origin, from: NSRect(origin: .zero, size: tinted.size), operation: .sourceOver, fraction: 1)
    }
    image.unlockFocus()
    return image
}
