import AppKit
import ServiceManagement
import SwiftUI

@main
struct HotEdgeMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            exit(SelfTest.run() ? 0 : 1)
        }
        Prefs.register()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = EdgeMonitor()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.updateIcon() } }

        monitor.start()

        if !UserDefaults.standard.bool(forKey: PrefKey.hasLaunchedBefore) {
            UserDefaults.standard.set(true, forKey: PrefKey.hasLaunchedBefore)
            showSettings()
        }
    }

    /// Launching the app again while it's running opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func updateIcon() {
        let name = Prefs.enabled ? "inset.filled.bottomthird.rectangle" : "rectangle"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Hot Edge")
            ?? NSImage(systemSymbolName: "rectangle", accessibilityDescription: "Hot Edge")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !Prefs.enabled
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(title: "Hot Edge Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.state = Prefs.enabled ? .on : .off
        toggle.target = self
        menu.addItem(toggle)

        let actionMenu = NSMenu()
        for action in EdgeAction.allCases {
            let item = NSMenuItem(title: action.title, action: #selector(chooseAction(_:)), keyEquivalent: "")
            item.representedObject = action.rawValue
            item.state = Prefs.action == action ? .on : .off
            item.target = self
            actionMenu.addItem(item)
        }
        let actionItem = NSMenuItem(title: "Action", action: nil, keyEquivalent: "")
        actionItem.submenu = actionMenu
        menu.addItem(actionItem)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.target = self
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Hot Edge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func toggleEnabled() {
        Prefs.enabled.toggle()
    }

    @objc private func chooseAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: PrefKey.action)
        if EdgeAction(rawValue: raw) == .openApp, Prefs.openAppPath.isEmpty { showSettings() }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change the login item"
            alert.runModal()
        }
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Hot Edge Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
