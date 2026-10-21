#if os(macOS)
import AppKit
import SwiftUI

@main
struct InputMeshApp: App {
    @StateObject private var appModel = InputMeshAppModel()
    @Environment(\.openWindow) private var openWindow

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
                Button("Open Workspace Handoff") { openWindow(id: "handoff") }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Refresh Local Status") { appModel.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        Window("Workspace Handoff", id: "handoff") {
            WorkspaceHandoffView()
        }
        .defaultSize(width: 750, height: 670)

        MenuBarExtra("InputMesh", systemImage: "arrow.left.arrow.right.square") {
            Text("InputMesh · Workspace preview")
            Text("Manual manifest transfer only · no LAN listener")
                .foregroundStyle(.secondary)
            Divider()
            Button("Open Workspace Handoff") { openWindow(id: "handoff") }
            Button("Open Dashboard") { openWindow(id: "dashboard") }
            Button("Refresh Local Status") { appModel.refresh() }
            Divider()
            Button("Quit InputMesh") { NSApplication.shared.terminate(nil) }
        }
    }
}

@MainActor
final class InputMeshAppModel: ObservableObject {
    @Published private(set) var currentHost: String = Host.current().localizedName ?? "This Mac"
    @Published private(set) var platformVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    @Published private(set) var refreshedAt: Date = Date()

    init() { refresh() }
    func refresh() {
        currentHost = Host.current().localizedName ?? "This Mac"
        platformVersion = ProcessInfo.processInfo.operatingSystemVersionString
        refreshedAt = Date()
    }

}
#endif
