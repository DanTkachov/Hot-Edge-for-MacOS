import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(PrefKey.enabled) private var enabled = true
    @AppStorage(PrefKey.action) private var action = EdgeAction.missionControl.rawValue
    @AppStorage(PrefKey.openAppPath) private var openAppPath = ""
    @AppStorage(PrefKey.activationMode) private var mode = ActivationMode.pressure.rawValue
    @AppStorage(PrefKey.pressureThreshold) private var pressure = 150
    @AppStorage(PrefKey.dwellTimeout) private var dwell = 250
    @AppStorage(PrefKey.edgeSize) private var edgeSize = 100
    @AppStorage(PrefKey.suppressWhenButtonHeld) private var suppressButton = true
    @AppStorage(PrefKey.suppressWhenFullscreen) private var suppressFullscreen = true
    @AppStorage(PrefKey.primaryMonitorOnly) private var primaryOnly = false
    @AppStorage(PrefKey.showAnimation) private var showAnimation = true

    @ObservedObject private var ui = SettingsUIState.shared

    var body: some View {
        Form {
            Section {
                Toggle("Hot edge enabled", isOn: $enabled)
                Picker("When the edge is hit, open", selection: $action) {
                    ForEach(EdgeAction.allCases) { Text($0.title).tag($0.rawValue) }
                }
                if action == EdgeAction.openApp.rawValue {
                    LabeledContent("App") {
                        HStack {
                            Text(openAppPath.isEmpty ? "None chosen"
                                 : FileManager.default.displayName(atPath: openAppPath))
                                .foregroundStyle(openAppPath.isEmpty ? .secondary : .primary)
                            Button("Choose…", action: chooseApp)
                        }
                    }
                }
            }

            Section("Behavior") {
                Picker("Activation", selection: $mode) {
                    ForEach(ActivationMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                if mode == ActivationMode.pressure.rawValue {
                    stepperRow("Activation pressure", value: $pressure, range: 0...500, step: 25, unit: "pixels",
                               help: "How far you push the cursor into the bottom edge, within one second.")
                } else {
                    stepperRow("Activation timeout", value: $dwell, range: 0...1000, step: 50, unit: "milliseconds",
                               help: "How long the cursor rests on the bottom edge.")
                }
                stepperRow("Edge size", value: $edgeSize, range: 1...100, step: 10, unit: "% of display width",
                           help: "The hot area stays centered. Lower values leave dead zones at the corners.")
                Toggle(isOn: $suppressButton) {
                    Text("Suppress on mouse button")
                    Text("Don't activate while a mouse button is held")
                }
                Toggle(isOn: $suppressFullscreen) {
                    Text("Suppress on fullscreen")
                    Text("Don't activate while an app is displayed in fullscreen mode")
                }
                Toggle("Hot edge only on the primary monitor", isOn: $primaryOnly)
                Toggle("Show animation when hot edge is activated", isOn: $showAnimation)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $ui.launchAtLogin)
                    .onChange(of: ui.launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError = ui.loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                LabeledContent("Try it") {
                    Button("Run action now") { EdgeAction(rawValue: action)?.perform() }
                }
            }

            if ui.dock.blocksBottomEdge {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Dock is on the bottom edge")
                            Text("It will pop up when you reach the edge. Move it to the left or right, or turn on auto-hide, in Desktop & Dock settings.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Open Desktop & Dock Settings…") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!)
                            }
                            .padding(.top, 2)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            ui.refresh()
        }
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int,
                            unit: String, help: String) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField("", value: value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .onSubmit { value.wrappedValue = min(range.upperBound, max(range.lowerBound, value.wrappedValue)) }
                Stepper("", value: value, in: range, step: step).labelsHidden()
            }
        } label: {
            Text(title)
            Text("\(unit) · \(help)")
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            openAppPath = url.path
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        guard on != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            ui.loginError = nil
        } catch {
            ui.loginError = "Couldn't change login item: \(error.localizedDescription)"
            ui.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// View state kept outside the view: the Command Line Tools toolchain has no
/// SwiftUI macro plugin, so `@State` isn't available when building without Xcode.
final class SettingsUIState: ObservableObject {
    static let shared = SettingsUIState()
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?
    @Published var dock = DockInfo.read()

    func refresh() {
        dock = DockInfo.read()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct DockInfo {
    var orientation: String
    var autohide: Bool
    var blocksBottomEdge: Bool { orientation == "bottom" && !autohide }

    static func read() -> DockInfo {
        let d = UserDefaults(suiteName: "com.apple.dock")
        return DockInfo(orientation: d?.string(forKey: "orientation") ?? "bottom",
                        autohide: d?.bool(forKey: "autohide") ?? false)
    }
}
