import AppKit
import QuartzCore

/// The activation ripple, modelled on GNOME Shell's `Ripples` (js/ui/ripples.js)
/// with the extension's `.ripple-centered` style: three translucent white
/// circles expanding from the point where the edge was hit.
@MainActor
enum Ripple {
    private static var live: [NSWindow] = []

    // (delay, duration, startScale, endScale) — same values as ripples.js.
    private static let specs: [(Double, Double, CGFloat, CGFloat)] = [
        (0.00, 0.83, 0.25, 1.50),
        (0.05, 1.00, 0.00, 1.25),
        (0.35, 1.00, 0.00, 1.00),
    ]

    static func play(at point: CGPoint) {
        let diameter: CGFloat = 104
        let side: CGFloat = 180
        let frame = NSRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)

        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        window.contentView = view

        let now = CACurrentMediaTime()
        let white = NSColor(white: 1, alpha: 0.2).cgColor
        for (delay, duration, from, to) in specs {
            let layer = CALayer()
            layer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            layer.position = CGPoint(x: side / 2, y: side / 2)
            layer.cornerRadius = diameter / 2
            layer.backgroundColor = white
            layer.borderColor = white
            layer.borderWidth = 2
            layer.opacity = 0
            view.layer?.addSublayer(layer)

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = from
            scale.toValue = to
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0

            let group = CAAnimationGroup()
            group.animations = [scale, fade]
            group.duration = duration
            group.beginTime = now + delay
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.fillMode = .backwards
            layer.add(group, forKey: "ripple")
        }

        window.orderFrontRegardless()
        live.append(window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            window.orderOut(nil)
            live.removeAll { $0 === window }
        }
    }
}
