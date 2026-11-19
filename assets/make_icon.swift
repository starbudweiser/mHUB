// Dessine l'icône de mHUB (1024 px) : un cœur jaune entouré de six satellites colorés, sur fond sombre arrondi.
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func c(_ h: UInt32) -> NSColor { NSColor(srgbRed: CGFloat((h >> 16) & 0xff) / 255, green: CGFloat((h >> 8) & 0xff) / 255, blue: CGFloat(h & 0xff) / 255, alpha: 1) }

let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let bg = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(starting: c(0x2b2b33), ending: c(0x131316))!.draw(in: bg, angle: -90)

let center = NSPoint(x: S / 2, y: S / 2)
c(0xf5b800).setFill()
NSBezierPath(ovalIn: NSRect(x: center.x - 120, y: center.y - 120, width: 240, height: 240)).fill()
let cols: [UInt32] = [0x7c6cff, 0xff7a59, 0x2fb36a, 0x19a7ce, 0xe0558a, 0x0a84ff]
for i in 0..<6 {
    let a = CGFloat(i) * .pi / 3 + .pi / 6
    let p = NSPoint(x: center.x + 290 * cos(a), y: center.y + 290 * sin(a))
    c(cols[i]).setFill()
    NSBezierPath(ovalIn: NSRect(x: p.x - 62, y: p.y - 62, width: 124, height: 124)).fill()
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
