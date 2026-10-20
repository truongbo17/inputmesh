#if os(macOS)
import AppKit
import SwiftUI
import ApplicationServices

@main
struct InputMeshApp: App {
    @StateObject private var appModel = InputMeshAppModel()

    var body: some Scene {
        WindowGroup("InputMesh", id: "dashboard") {
            DashboardView()
                .environmentObject(appModel)
                .frame(minWidth: 900, minHeight: 610)
        }
        .defaultSize(width: 1050, height: 690)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("InputMesh") {
                Button("Refresh Diagnostics") { appModel.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Open Accessibility Settings") { appModel.openAccessibilitySettings() }
            }
        }

        MenuBarExtra("InputMesh", systemImage: "cursorarrow.rays") {
            Text("InputMesh · Local mode")
            Text("Remote control is not enabled in this preview")
                .foregroundStyle(.secondary)
            Divider()
            Button("Open InputMesh") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                for window in NSApplication.shared.windows where window.canBecomeMain { window.makeKeyAndOrderFront(nil) }
            }
            Button("Refresh Permissions") { appModel.refresh() }
            Divider()
            Button("Quit InputMesh") { NSApplication.shared.terminate(nil) }
        }
    }
}

@MainActor
final class InputMeshAppModel: ObservableObject {
    @Published private(set) var accessibilityAllowed: Bool = false
    @Published private(set) var currentHost: String = Host.current().localizedName ?? "This Mac"
    @Published private(set) var platformVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    @Published private(set) var refreshedAt: Date = Date()

    init() { refresh() }

    func refresh() {
        accessibilityAllowed = AXIsProcessTrusted()
        currentHost = Host.current().localizedName ?? "This Mac"
        platformVersion = ProcessInfo.processInfo.operatingSystemVersionString
        refreshedAt = Date()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
