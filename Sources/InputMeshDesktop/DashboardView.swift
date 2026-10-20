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
    case layout = "Screen Layout"
    case security = "Security"
    case about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .devices: "desktopcomputer"
        case .layout: "rectangle.3.group"
        case .security: "lock.shield"
        case .about: "info.circle"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: InputMeshAppModel
    @State private var page: DashboardPage = .overview

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("InputMesh").font(.headline.weight(.bold))
                        Text("ONE INPUT · EVERY DESKTOP")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "cursorarrow.rays")
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
                    Label("Local mode", systemImage: "checkmark.shield")
                        .foregroundStyle(.green).font(.caption.weight(.semibold))
                    Text("No remote input is accepted")
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
                    case .layout: layout
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
            heading("Workspace overview", subtitle: "A secure home for your connected desktops.")
            HStack(spacing: 14) {
                statCard("Local computer", value: "1", symbol: "desktopcomputer", note: "Available for diagnostics")
                statCard("Trusted devices", value: "0", symbol: "link", note: "Pairing is not available yet")
                statCard("Control state", value: "Local", symbol: "cursorarrow", note: "Input stays on this Mac")
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your workspace").font(.title3.weight(.semibold))
                    Spacer()
                    Text("PREVIEW · NO REMOTE CONTROL").font(.caption2.weight(.bold))
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
                                Text("Pairing in a future build")
                                    .font(.caption2)
                            }.foregroundStyle(.secondary)
                        }
                }
                Text("Input is never sent to unpaired devices. This preview cannot control another Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .panel()
            permissionPanel
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
                    Text("Encrypted pairing and multi-device control are under development.")
                        .foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 190)
            }.panel()
        }
    }

    private var layout: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Screen layout", subtitle: "Arrange your displays when pairing becomes available.")
            VStack(spacing: 14) {
                Text("Topology preview").font(.headline)
                MacTile(title: model.currentHost, description: "Current display owner", active: true)
                    .frame(maxWidth: 370)
                Text("Multi-display editing is planned. No devices are connected in this build.")
                    .font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(40).panel()
        }
    }

    private var security: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Security & privacy", subtitle: "Your keyboard input must remain under your control.")
            permissionPanel
            VStack(alignment: .leading, spacing: 14) {
                Label("Remote input disabled", systemImage: "lock.shield.fill")
                    .font(.headline).foregroundStyle(.green)
                Text("This preview does not listen on the network or accept remote events. Future versions will require an explicitly trusted peer and an authenticated, encrypted session.")
                Text("The passive diagnostic probe records event counts only; it does not store text, key codes, or cursor coordinates.")
                    .foregroundStyle(.secondary)
            }.panel()
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("About InputMesh", subtitle: "One input. Every desktop.")
            VStack(alignment: .leading, spacing: 12) {
                Label("Native macOS diagnostic preview", systemImage: "hammer")
                    .font(.headline)
                Text("Status: development preview · Cross-device control is NOT available")
                Text("Architecture: Swift core, cross-platform contracts, macOS Quartz adapter")
                Text("Source: github.com/truongbo17/inputmesh")
            }.panel()
        }
    }

    private var permissionPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Device readiness").font(.title3.weight(.semibold))
                Spacer()
                Button { model.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
            }
            HStack(spacing: 12) {
                Image(systemName: model.accessibilityAllowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(model.accessibilityAllowed ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessibility permission").font(.subheadline.weight(.semibold))
                    Text(model.accessibilityAllowed ? "Granted to the current process" : "Not granted to the current process")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open Settings") { model.openAccessibilitySettings() }
                    .buttonStyle(.borderedProminent)
            }
            Divider()
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle").foregroundStyle(UIStyle.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input Monitoring").font(.subheadline.weight(.semibold))
                    Text("This permission must be checked in System Settings and validated using the passive native probe; it cannot be inferred from Accessibility alone.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }.panel()
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
