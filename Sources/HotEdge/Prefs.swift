import Foundation

enum ActivationMode: String, CaseIterable, Identifiable {
    case pressure, dwell
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pressure: "Push into the edge (pressure)"
        case .dwell: "Rest on the edge (timeout)"
        }
    }
}

enum PrefKey {
    static let enabled = "enabled"
    static let action = "action"
    static let openAppPath = "openAppPath"
    static let activationMode = "activationMode"
    static let pressureThreshold = "pressureThreshold"
    static let dwellTimeout = "dwellTimeout"
    static let edgeSize = "edgeSize"
    static let suppressWhenButtonHeld = "suppressWhenButtonHeld"
    static let suppressWhenFullscreen = "suppressWhenFullscreen"
    static let primaryMonitorOnly = "primaryMonitorOnly"
    static let showAnimation = "showAnimation"
    static let hasLaunchedBefore = "hasLaunchedBefore"
}

/// Settings mirror the original gschema (org.gnome.shell.extensions.hotedge),
/// with the same defaults.
enum Prefs {
    private static var d: UserDefaults { .standard }

    static func register() {
        d.register(defaults: [
            PrefKey.enabled: true,
            PrefKey.action: EdgeAction.missionControl.rawValue,
            PrefKey.openAppPath: "",
            PrefKey.activationMode: ActivationMode.pressure.rawValue,
            PrefKey.pressureThreshold: 150, // px, gschema default
            PrefKey.dwellTimeout: 250,      // ms, gschema default
            PrefKey.edgeSize: 100,          // % of display width
            PrefKey.suppressWhenButtonHeld: true,
            PrefKey.suppressWhenFullscreen: true,
            PrefKey.primaryMonitorOnly: false,
            PrefKey.showAnimation: true,
        ])
    }

    static var enabled: Bool {
        get { d.bool(forKey: PrefKey.enabled) }
        set { d.set(newValue, forKey: PrefKey.enabled) }
    }
    static var action: EdgeAction { EdgeAction(rawValue: d.string(forKey: PrefKey.action) ?? "") ?? .missionControl }
    static var openAppPath: String { d.string(forKey: PrefKey.openAppPath) ?? "" }
    static var activationMode: ActivationMode {
        ActivationMode(rawValue: d.string(forKey: PrefKey.activationMode) ?? "") ?? .pressure
    }
    static var pressureThreshold: Double { Double(d.integer(forKey: PrefKey.pressureThreshold)) }
    static var dwellTimeout: TimeInterval { Double(d.integer(forKey: PrefKey.dwellTimeout)) / 1000 }
    static var edgeSize: Double { min(100, max(1, Double(d.integer(forKey: PrefKey.edgeSize)))) / 100 }
    static var suppressWhenButtonHeld: Bool { d.bool(forKey: PrefKey.suppressWhenButtonHeld) }
    static var suppressWhenFullscreen: Bool { d.bool(forKey: PrefKey.suppressWhenFullscreen) }
    static var primaryMonitorOnly: Bool { d.bool(forKey: PrefKey.primaryMonitorOnly) }
    static var showAnimation: Bool { d.bool(forKey: PrefKey.showAnimation) }
}
