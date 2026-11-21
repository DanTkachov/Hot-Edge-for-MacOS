import AppKit

/// What the hot edge does when it fires.
enum EdgeAction: String, CaseIterable, Identifiable {
    case missionControl, appExpose, launchpad, showDesktop, openApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missionControl: "Mission Control"
        case .appExpose: "App Exposé (current app's windows)"
        case .launchpad: "Apps / Launchpad"
        case .showDesktop: "Show Desktop"
        case .openApp: "Open an App…"
        }
    }

    @MainActor
    func perform() {
        switch self {
        case .missionControl:
            if !Dock.send("com.apple.expose.awake") {
                Self.open(path: "/System/Applications/Mission Control.app")
            }
        case .appExpose:
            Dock.send("com.apple.expose.front.awake")
        case .launchpad:
            let candidates = [
                "/System/Applications/Apps.app",
                "/System/Applications/Launchpad.app",
            ]
            if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                Self.open(path: path)
            } else {
                Dock.send("com.apple.launchpad.toggle")
            }
        case .showDesktop:
            Dock.send("com.apple.showdesktop.awake")
        case .openApp:
            let path = Prefs.openAppPath
            if !path.isEmpty { Self.open(path: path) }
        }
    }

    private static func open(path: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config)
    }
}

/// The Dock's own notification channel. It's what the Dock uses internally
/// for Mission Control / Exposé, and these calls act as toggles: firing
/// again closes the view, just like GNOME's `Main.overview.toggle()`.
private enum Dock {
    private typealias SendFn = @convention(c) (CFString, Int32) -> Void

    private static let sendFn: SendFn? = {
        let path = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        guard let handle = dlopen(path, RTLD_LAZY),
              let sym = dlsym(handle, "CoreDockSendNotification") else { return nil }
        return unsafeBitCast(sym, to: SendFn.self)
    }()

    @discardableResult
    static func send(_ name: String) -> Bool {
        guard let sendFn else { return false }
        sendFn(name as CFString, 0)
        return true
    }
}
