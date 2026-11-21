// Renders the app icon: a screen with a glowing bottom edge and a ripple.
// Usage: swift make_icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let inset: CGFloat = 100
let tile = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.42, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.20, alpha: 1),
])!.draw(in: tilePath, angle: -90)

// Screen
let screen = NSRect(x: 230, y: 300, width: 564, height: 420)
NSColor(white: 1, alpha: 0.10).setFill()
NSBezierPath(roundedRect: screen, xRadius: 36, yRadius: 36).fill()
NSColor(white: 1, alpha: 0.55).setStroke()
let frame = NSBezierPath(roundedRect: screen, xRadius: 36, yRadius: 36)
frame.lineWidth = 14
frame.stroke()

// Ripple rings at the bottom edge
NSGraphicsContext.saveGraphicsState()
NSBezierPath(rect: NSRect(x: 0, y: screen.minY, width: size, height: size)).addClip()
for (r, a) in [(150.0, 0.18), (105.0, 0.28), (60.0, 0.45)] {
    let c = NSRect(x: 512 - r, y: screen.minY - r, width: 2 * r, height: 2 * r)
    NSColor(white: 1, alpha: a).setFill()
    NSBezierPath(ovalIn: c).fill()
}
NSGraphicsContext.restoreGraphicsState()

// Hot edge
let edge = NSRect(x: screen.minX + 10, y: screen.minY - 14, width: screen.width - 20, height: 30)
NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.25, alpha: 1).setFill()
NSBezierPath(roundedRect: edge, xRadius: 15, yRadius: 15).fill()

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
