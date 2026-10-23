import AppKit

guard CommandLine.arguments.count == 2 else { fatalError("Provide an iconset output directory") }
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: 976, height: 976), xRadius: 220, yRadius: 220)
        NSGradient(starting: NSColor(calibratedRed: 0.23, green: 0.80, blue: 0.55, alpha: 1), ending: NSColor(calibratedRed: 0.07, green: 0.48, blue: 0.33, alpha: 1))!
            .draw(in: background, angle: -60)
        let pointer = NSBezierPath()
        pointer.move(to: NSPoint(x: 340, y: 790))
        pointer.line(to: NSPoint(x: 340, y: 285))
        pointer.line(to: NSPoint(x: 465, y: 402))
        pointer.line(to: NSPoint(x: 559, y: 217))
        pointer.line(to: NSPoint(x: 654, y: 265))
        pointer.line(to: NSPoint(x: 561, y: 449))
        pointer.line(to: NSPoint(x: 728, y: 467))
        pointer.close()
        NSColor.white.setFill()
        pointer.fill()
        let motion = NSBezierPath()
        motion.lineWidth = 34
        motion.lineCapStyle = .round
        for offset in [0, 100] {
            motion.move(to: NSPoint(x: 610 + offset, y: 745))
            motion.line(to: NSPoint(x: 690 + offset, y: 665))
        }
        NSColor.white.withAlphaComponent(0.7).setStroke()
        motion.stroke()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
