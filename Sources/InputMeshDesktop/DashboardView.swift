#if os(macOS)
import SwiftUI

private enum UIStyle {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let canvas = Color(nsColor: .controlBackgroundColor)
    static let accent = Color(red: 0.16, green: 0.49, blue: 0.87)
    static let subtle = Color(nsColor: .secondaryLabelColor)
}

private enum DashboardPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case devices = "Devices"
    case handoff = "Handoff Guide"
    case security = "Security"
    case about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .devices: "desktopcomputer"
        case .handoff: "arrow.left.arrow.right.square"
        case .security: "lock.shield"
        case .about: "info.circle"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: InputMeshAppModel
    @State private var page: DashboardPage = .overview
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("InputMesh").font(.headline.weight(.bold))
                        Text("CONTINUE YOUR WORKSPACE")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.left.arrow.right.square")
                        .font(.title2).foregroundStyle(UIStyle.accent)
                }
                .padding(.horizontal, 9)
                .padding(.top, 16)

                List(DashboardPage.allCases, selection: $page) { item in
                    Label(item.rawValue, systemImage: item.symbol).tag(item)
                }
                .listStyle(.sidebar)
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    Label("Local preview", systemImage: "checkmark.shield")
                        .foregroundStyle(.green).font(.caption.weight(.semibold))
                    Text("No listener by default · no remote commands")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(UIStyle.canvas.opacity(0.65), in: RoundedRectangle(cornerRadius: 11))
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 260)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch page {
                    case .overview: overview
                    case .devices: devices
                    case .handoff: handoffGuide
                    case .security: security
                    case .about: about
                    }
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(UIStyle.background)
        }
        .navigationTitle("InputMesh")
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Workspace overview", subtitle: "Safely continue an existing Git project on another device.")
            Button { openWindow(id: "handoff") } label: {
                Label("Open Workspace Handoff", systemImage: "arrow.left.arrow.right.square")
            }.buttonStyle(.borderedProminent)
            Button { openWindow(id: "lan") } label: {
                Label("Experimental Secure LAN Handoff…", systemImage: "network")
            }.buttonStyle(.bordered)
            HStack(spacing: 14) {
                statCard("This Mac", value: "Local", symbol: "desktopcomputer", note: "Selected Git repositories only")
                statCard("Transfer method", value: "AirDrop / File", symbol: "square.and.arrow.up", note: "User-approved JSON handoff")
                statCard("Peer transport", value: "Opt-in beta", symbol: "lock.shield", note: "Manual IP · dual approval · no automatic listener")
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your workspace").font(.title3.weight(.semibold))
                    Spacer()
                    Text("MANUAL WORKSPACE HANDOFF").font(.caption2.weight(.bold))
                        .foregroundStyle(UIStyle.subtle)
                }
                HStack(alignment: .center, spacing: 16) {
                    MacTile(title: model.currentHost, description: "This Mac · Local", active: true)
                    Image(systemName: "arrow.left.and.right")
                        .font(.title2).foregroundStyle(.tertiary)
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132)
                        .overlay {
                            VStack(spacing: 7) {
                                Image(systemName: "plus.circle.dashed").font(.title2)
                                Text("Another Mac")
                                    .font(.subheadline.weight(.medium))
                                Text("Automatic pairing not available")
                                    .font(.caption2)
                            }.foregroundStyle(.secondary)
                        }
                }
                Text("Capture Git metadata, transfer it manually, inspect an existing clean clone and explicitly open VS Code. No source files or unsaved buffers are transferred.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .panel()
            Label("No Accessibility or Input Monitoring permission is required for Workspace Handoff.", systemImage: "lock.shield")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var devices: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Devices", subtitle: "Manage computers you explicitly trust.")
            VStack(alignment: .leading, spacing: 14) {
                Label(model.currentHost, systemImage: "laptopcomputer")
                    .font(.headline)
                Text("This Mac · macOS · Diagnostic mode")
                    .foregroundStyle(.secondary)
                Divider()
                VStack(spacing: 10) {
                    Image(systemName: "network.slash").font(.system(size: 34)).foregroundStyle(.secondary)
                    Text("No trusted peers").font(.headline)
                    Text("Bonjour discovery is not available. Experimental encrypted pairing by manual LAN IP requires explicit action on both Macs.")
                    Button { openWindow(id: "lan") } label: {
                        Label("Open LAN Pairing Beta", systemImage: "network")
                    }.buttonStyle(.bordered)
                        .foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 190)
            }.panel()
        }
    }

    private var handoffGuide: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Handoff guide", subtitle: "Safely continue an existing Git project on another Mac.")
            VStack(alignment: .leading, spacing: 14) {
                Label("1 · Export", systemImage: "square.and.arrow.up")
                Text("Select a local Git repository and save its JSON manifest outside the repository.")
                Label("2 · Transfer", systemImage: "arrow.left.arrow.right")
                Text("Use AirDrop or a trusted file-transfer channel; manifests are not encrypted.")
                Label("3 · Validate", systemImage: "checkmark.shield")
                Text("On the destination Mac select an existing clone. Dirty worktrees, different branches or commits block handoff.")
                Label("4 · Continue", systemImage: "arrow.up.right.square")
                Text("Explicitly open the matching project in Visual Studio Code. Git is never automatically reset or pulled.")
                Button { openWindow(id: "handoff") } label: {
                    Label("Open Workspace Handoff", systemImage: "arrow.left.arrow.right.square")
                }.buttonStyle(.borderedProminent)
            }.panel()
        }
    }
    private var security: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Privacy & security", subtitle: "Local-first Git context without privileged keyboard access.")
            VStack(alignment: .leading, spacing: 12) {
                Label("No keyboard monitoring needed", systemImage: "keyboard")
                    .font(.headline)
                Text("Workspace Handoff reads Git metadata from a folder you explicitly select. It does not need Accessibility or Input Monitoring permissions.")
                Divider()
                Label("No automatic remote commands", systemImage: "lock.shield")
                    .font(.headline)
                Text("No listener starts automatically, and no remote shell, source-file transfer, checkout, pull or reset is enabled. An experimental LAN pairing window requires explicit user consent.")
                Divider()
                Label("Manual JSON is not encrypted", systemImage: "doc.text")
                    .font(.headline)
                Text("Git origin, branch, commit and optional HTTPS links may reveal private project metadata; share only via a trusted channel.")
            }.panel()
        }
    }
    private var about: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("About InputMesh", subtitle: "Continue your workspace on another device.")
            VStack(alignment: .leading, spacing: 12) {
                Label("Workspace Handoff developer preview", systemImage: "hammer").font(.headline)
                Text("Available: manual Git manifest export/import, conflict checks and explicit local VS Code open.")
                Text("Experimental: manual-IP encrypted LAN handoff, requiring both users to compare and approve SAS. No hardware certification or notarized stable installer yet.")
                Text("Source: github.com/truongbo17/inputmesh")
            }.panel()
        }
    }
    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 29, weight: .bold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func statCard(_ label: String, value: String, symbol: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(label, systemImage: symbol)
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(17)
        .background(UIStyle.canvas, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.primary.opacity(0.07)))
    }
}

private struct MacTile: View {
    let title: String
    let description: String
    let active: Bool
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(red: 0.12, green: 0.19, blue: 0.32))
                    .frame(width: 118, height: 75)
                    .overlay {
                        Image(systemName: "cursorarrow.rays")
                            .font(.title).foregroundStyle(.white.opacity(0.84))
                    }
                RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.2))
                    .frame(width: 118, height: 75)
            }
            VStack(spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 132)
        .background(active ? Color.accentColor.opacity(0.07) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(active ? Color.accentColor.opacity(0.55) : Color.gray.opacity(0.2)))
    }
}

private struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.primary.opacity(0.07)))
    }
}

private extension View {
    func panel() -> some View { modifier(PanelModifier()) }
}
#endif
