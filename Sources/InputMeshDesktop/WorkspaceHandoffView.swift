#if os(macOS)
import AppKit
import UniformTypeIdentifiers
import SwiftUI
import InputMeshWorkspace

@MainActor
final class WorkspaceHandoffModel: ObservableObject {
    @Published var sourceFolder: URL?
    @Published var manifestFile: URL?
    @Published var exportedManifestURL: URL?
    @Published var destinationFolder: URL?
    @Published var sourceManifest: WorkspaceManifest?
    @Published var plan: HandoffPlan?
    @Published var browserURLText = ""
    @Published var message = "Choose an existing local Git repository to capture."
    @Published var errorMessage: String?

    func chooseSourceAndExport() {
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.prompt = "Choose Git repository"
        guard picker.runModal() == .OK, let source = picker.url else { return }
        let save = NSSavePanel()
        save.title = "Export a safe InputMesh workspace manifest"
        save.nameFieldStringValue = "workspace.inputmesh.json"
        guard save.runModal() == .OK, let output = save.url else { return }
        do {
            let resources: [WorkspaceResource] = browserURLText.isEmpty ? [] : [.webURL(browserURLText)]
            let snapshot = try WorkspaceCommand.capture(repository: source, output: output,
                  deviceName: Host.current().localizedName ?? "This Mac", resources: resources)
            sourceFolder = source
            sourceManifest = snapshot
            exportedManifestURL = output
            message = "Exported metadata to \(output.lastPathComponent). Transfer this small JSON file using AirDrop or another trusted channel. No source files were copied."
            errorMessage = nil
            if snapshot.repository.hasUncommittedChanges || snapshot.repository.hasUntrackedFiles {
                message += " WARNING: Source contains local changes; handoff cannot continue until resolved."
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func shareViaAirDrop() {
        guard let fileURL = exportedManifestURL else { return }
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            errorMessage = "AirDrop is not available. Share the exported JSON manually."
            return
        }
        service.perform(withItems: [fileURL])
        message = "AirDrop opened. Confirm the receiving Mac and import the file there."
    }

    func openReference(_ text: String) {
        guard let url = URL(string: text) else { return }
        do {
            try WorkspaceResource.webURL(text).validate()
            NSWorkspace.shared.open(url)
        } catch { errorMessage = error.localizedDescription }
    }

    func chooseIncomingManifest() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.json]
        picker.canChooseDirectories = false
        picker.title = "Select workspace manifest received from another Mac"
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            sourceManifest = try WorkspaceManifest.load(url)
            manifestFile = url
            destinationFolder = nil
            plan = nil
            errorMessage = nil
            message = "Manifest loaded. Choose a local destination Git repository to check for conflicts."
        } catch { errorMessage = error.localizedDescription }
    }

    func chooseDestinationAndCheck() {
        guard let manifestFile = manifestFile else { return }
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.title = "Choose the existing local clone on this Mac"
        guard picker.runModal() == .OK, let folder = picker.url else { return }
        do {
            let result = try WorkspaceCommand.inspect(manifestURL: manifestFile, destination: folder)
            destinationFolder = folder
            plan = result
            errorMessage = nil
            message = result.canOpen ? "Ready. Same repository, branch and commit; both working trees recorded clean." :
                "Handoff blocked. Resolve differences manually. No files were changed."
        } catch {
            plan = nil
            errorMessage = error.localizedDescription
        }
    }

    func continueOnThisMac() {
        guard let manifestFile = manifestFile, let folder = destinationFolder else { return }
        do {
            let current = try WorkspaceCommand.continueOnThisDevice(manifestURL: manifestFile, destination: folder)
            plan = current
            message = current.canOpen ? "Requested VS Code to open the existing matching repository." :
                "Repository changed since validation; handoff blocked."
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

struct WorkspaceHandoffView: View {
    @StateObject private var model = WorkspaceHandoffModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right.square.fill")
                        .font(.system(size: 34)).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workspace Handoff").font(.largeTitle.bold())
                        Text("Continue an existing Git project on another Mac — without rewriting files.")
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                GroupBox("1 · Capture on this Mac") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Save metadata: repository origin, branch, commit, dirty state and one optional HTTPS resource. No code files, passwords or unsaved buffers are included.")
                            .foregroundStyle(.secondary)
                        TextField("Optional HTTPS page (for reference only)", text: $model.browserURLText)
                            .textFieldStyle(.roundedBorder)
                        Button { model.chooseSourceAndExport() } label: {
                            Label("Choose Git repo and export manifest…", systemImage: "square.and.arrow.up")
                        }.buttonStyle(.borderedProminent)
                        if model.exportedManifestURL != nil {
                            Button { model.shareViaAirDrop() } label: {
                                Label("Send manifest with AirDrop…", systemImage: "airplayaudio")
                            }.buttonStyle(.bordered)
                        }
                        if let manifest = model.sourceManifest, model.manifestFile == nil {
                            Label("\(manifest.repository.branch) · \(manifest.repository.headSHA.prefix(10))", systemImage: "checkmark.shield")
                                .font(.callout)
                        }
                    }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("2 · Inspect on destination Mac") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AirDrop or copy the manifest to the other Mac, then import it. The destination must already have a local clone at the exact Git commit and branch.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button { model.chooseIncomingManifest() } label: {
                                Label("Import manifest…", systemImage: "square.and.arrow.down")
                            }
                            Button { model.chooseDestinationAndCheck() } label: {
                                Label("Choose destination repo…", systemImage: "folder")
                            }.disabled(model.manifestFile == nil)
                        }
                        if let plan = model.plan {
                            if plan.canOpen {
                                Label("Ready — no conflicts", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                ForEach(plan.blockers, id: \.self) { blocker in
                                    Label(blocker.rawValue, systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        if let plan = model.plan, plan.canOpen, !plan.resources.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Optional web references — open individually after review")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(plan.resources.indices, id: \.self) { index in
                                    switch plan.resources[index] {
                                    case .webURL(let text):
                                        Button { model.openReference(text) } label: {
                                            Label(text, systemImage: "globe")
                                        }.buttonStyle(.link)
                                    }
                                }
                            }
                        }
                        Button { model.continueOnThisMac() } label: {
                            Label("Continue in Visual Studio Code", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.plan?.canOpen != true)
                    }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                }
                if let error = model.errorMessage {
                    Label(error, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
                Text(model.message).font(.callout)
                Text("LOCAL PREVIEW · No peer pairing, automatic sync, clone, pull, checkout or file transfer. No background network listener.")
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }.padding(28)
        }
        .frame(minWidth: 680, minHeight: 620)
    }
}
#endif
