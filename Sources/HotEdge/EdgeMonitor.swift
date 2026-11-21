import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

/// Watches the pointer and fires the configured action when it is pushed
/// into (or rests on) the bottom edge of a screen.
@MainActor
final class EdgeMonitor {
    /// How close (in points) to a screen's bottom the pointer must be to count
    /// as "on the edge". The clamped cursor sits within a point of the bottom.
    private static let edgeTolerance: CGFloat = 2

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var barrier = PressureBarrier()
    private var activeScreen: CGDirectDisplayID?
    private var dwellTimer: Timer?

    func start() {
        guard globalMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        leaveEdge()
    }

    // MARK: - Event handling

    private func handle(_ event: NSEvent) {
        guard Prefs.enabled else { leaveEdge(); return }

        let location = NSEvent.mouseLocation
        guard let screen = Self.hotScreen(at: location), let id = screen.displayID else {
            leaveEdge()
            return
        }

        if activeScreen != id {
            leaveEdge()
            enterEdge(screen: screen, id: id)
        }

        if Prefs.activationMode == .pressure {
            // NSEvent deltas keep arriving while the cursor is pinned at the
            // edge; positive deltaY means "moving down" (into the edge).
            let fired = barrier.hit(
                time: event.timestamp,
                across: Double(event.deltaY),
                along: Double(abs(event.deltaX)),
                threshold: Prefs.pressureThreshold
            )
            if fired { fire(on: screen) }
        }
    }

    private func enterEdge(screen: NSScreen, id: CGDirectDisplayID) {
        activeScreen = id
        barrier.reset()
        if Prefs.activationMode == .dwell {
            dwellTimer = Timer.scheduledTimer(withTimeInterval: Prefs.dwellTimeout, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.activeScreen == id,
                          let screen = NSScreen.screens.first(where: { $0.displayID == id }) else { return }
                    self.fire(on: screen)
                }
            }
        }
    }

    private func leaveEdge() {
        activeScreen = nil
        barrier.reset()
        dwellTimer?.invalidate()
        dwellTimer = nil
    }

    private func fire(on screen: NSScreen) {
        if Prefs.suppressWhenButtonHeld, NSEvent.pressedMouseButtons & 0b111 != 0 { return }
        if Prefs.suppressWhenFullscreen, FullscreenDetector.frontmostAppIsFullscreen(on: screen) { return }

        Prefs.action.perform()

        if Prefs.showAnimation {
            Ripple.play(at: CGPoint(x: NSEvent.mouseLocation.x, y: screen.frame.minY))
        }
    }

    // MARK: - Geometry

    /// The screen whose hot edge the pointer is on, or nil.
    static func hotScreen(at p: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        guard let screen = screens.first(where: { s in
            p.x >= s.frame.minX && p.x < s.frame.maxX &&
                p.y >= s.frame.minY - 1 && p.y <= s.frame.minY + edgeTolerance
        }) else { return nil }

        // "Primary monitor" = the one with the menu bar, always screens[0].
        if Prefs.primaryMonitorOnly, screen != screens.first { return nil }

        // Like the original: no hot edge when another monitor sits directly
        // below, because the edge would block moving the cursor onto it.
        // (Cocoa coordinates: y grows upward.)
        let f = screen.frame
        let hasScreenBelow = screens.contains { other in
            other != screen && other.frame.maxY <= f.minY + 1 &&
                other.frame.minX < f.maxX && other.frame.maxX > f.minX
        }
        if hasScreenBelow { return nil }

        // The hot region is centered; edge-size < 100% leaves dead zones at
        // the corners.
        let width = f.width * Prefs.edgeSize
        let x0 = f.midX - width / 2
        guard p.x >= x0, p.x <= x0 + width else { return nil }

        return screen
    }
}

enum FullscreenDetector {
    /// True if the frontmost app has a window covering the whole display,
    /// e.g. a fullscreen video, game or fullscreen Space.
    static func frontmostAppIsFullscreen(on screen: NSScreen) -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let id = screen.displayID,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }

        let display = CGDisplayBounds(id)
        for w in windows {
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict) else { continue }
            if abs(bounds.minX - display.minX) < 1, abs(bounds.minY - display.minY) < 1,
               abs(bounds.width - display.width) < 1, abs(bounds.height - display.height) < 1 {
                return true
            }
        }
        return false
    }
}
