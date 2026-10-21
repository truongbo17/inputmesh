#if os(macOS)
import AppKit
import Foundation
import Network
import SwiftUI
import InputMeshMacOS
import InputMeshWorkspace

/// Explicitly opt-in, single-peer LAN beta. Not enabled at app startup.
/// Incoming Git context is always inert until the receiver chooses a clone.
@MainActor
final class WorkspaceLANModel: ObservableObject {
    static let portNumber: UInt16 = 48437
    private static var port: NWEndpoint.Port { NWEndpoint.Port(rawValue: portNumber)! }

    @Published var remoteHost = ""
    @Published private(set) var message = "Start a temporary listener on Mac B, then enter its LAN IP on Mac A."
    @Published private(set) var pairingCode: String?
    @Published private(set) var connected = false
    @Published private(set) var listening = false
    @Published private(set) var incomingManifest: WorkspaceManifest?
    @Published private(set) var destinationFolder: URL?
    @Published private(set) var plan: HandoffPlan?
    @Published var errorMessage: String?

    private let trustStore = WorkspacePeerTrustStore()
    private let listenerQueue = DispatchQueue(label: "dev.inputmesh.workspace.listener")
    private var listener: NWListener?
    private var listenerGeneration = UUID()
    private var transport: WorkspaceTCPTransport?
    private var coordinator: WorkspaceConsentCoordinator?
    private var peerPublicKey: Data?

    func startListening() {
        guard listener == nil, transport == nil else { return }
        do {
            let server = try NWListener(using: .tcp, on: Self.port)
            let generation = UUID()
            listenerGeneration = generation
            server.newConnectionHandler = { [weak self] connection in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.listenerGeneration == generation else {
                        connection.cancel()
                        return
                    }
                    if self.transport != nil {
                        connection.cancel()
                        return
                    }
                    do {
                        try self.attach(connection: connection, role: .responder)
                        self.stopListening()
                    } catch {
                        connection.cancel()
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            server.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.listenerGeneration == generation else { return }
                    switch state {
                    case .ready:
                        self.listening = true
                        self.message = "Pairing listener active on port \(Self.portNumber). Confirm the matching code on both Macs."
                    case .failed(let error):
                        self.errorMessage = error.localizedDescription
                        self.stopListening()
                    default:
                        break
                    }
                }
            }
            listener = server
            server.start(queue: listenerQueue)
            // No indefinite network listener. Accepted connections are managed
            // separately; shutting down discovery never closes an active peer.
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self, self.listenerGeneration == generation else { return }
                if self.listening {
                    self.stopListening()
                    self.message = "Pairing window expired. Start it again to accept a new connection."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        listenerGeneration = UUID()
        listener?.cancel()
        listener = nil
        listening = false
    }

    func connect() {
        guard transport == nil else { return }
        let host = remoteHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, host.utf8.count <= 255,
              !host.contains("/"), !host.contains("@"), !host.contains(" ") else {
            errorMessage = "Enter a LAN IP address or hostname without a URL scheme."
            return
        }
        do {
            let connection = NWConnection(host: NWEndpoint.Host(host), port: Self.port, using: .tcp)
            try attach(connection: connection, role: .initiator)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func attach(connection: NWConnection, role: WorkspaceSessionRole) throws {
        let identity = try MacDeviceIdentity.loadOrCreateInKeychain()
        let coordinator = try WorkspaceConsentCoordinator(identity: identity, role: role, trustStore: trustStore)
        self.coordinator = coordinator
        let transport = WorkspaceTCPTransport(connection: connection, coordinator: coordinator,
            onEvent: { [weak self] event in
                DispatchQueue.main.async { [weak self] in self?.handle(event) }
            }, onError: { [weak self] error in
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Secure session ended: \(error.localizedDescription)"
                    self?.connected = false
                    self?.pairingCode = nil
                    self?.transport = nil
                    self?.coordinator = nil
                }
            })
        self.transport = transport
        pairingCode = nil
        connected = false
        errorMessage = nil
        message = "Connecting. Verify the pairing code independently on both Macs."
        transport.start()
    }

    private func handle(_ event: WorkspaceConsentEvent) {
        switch event {
        case .pairingCode(let code):
            pairingCode = code
            message = "Compare this code on both Macs. Approve only if the code matches exactly."
        case .ready:
            connected = true
            pairingCode = nil
            peerPublicKey = coordinator?.verifiedPeerPublicKey
            message = "Both Macs approved. You may send a clean Git workspace manifest."
        case .manifest(let manifest):
            incomingManifest = manifest
            destinationFolder = nil
            plan = nil
            message = "Encrypted manifest received. Choose an existing local clone to inspect; nothing is opened automatically."
        case .closed:
            connected = false
            pairingCode = nil
            transport?.stop()
            transport = nil
            coordinator = nil
            message = "Peer disconnected."
        }
    }

    func approvePairing() {
        guard let pairingCode, let transport else { return }
        transport.approveMatchingCode(pairingCode)
        message = "Local approval sent. Waiting for the other Mac's encrypted approval."
    }

    func sendSelectedWorkspace() {
        guard connected, let transport else { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.prompt = "Choose clean Git repository"
        guard picker.runModal() == .OK, let folder = picker.url else { return }
        do {
            let manifest = try GitWorkspaceInspector().capture(
                at: folder, deviceName: Host.current().localizedName ?? "This Mac")
            guard !manifest.repository.hasUncommittedChanges,
                  !manifest.repository.hasUntrackedFiles else {
                message = "Handoff blocked: the source has uncommitted or untracked changes."
                return
            }
            transport.sendManifest(manifest)
            message = "Encrypted manifest queued for the trusted peer; waiting for receiver review."
        } catch { errorMessage = error.localizedDescription }
    }

    func inspectIncoming() {
        guard let incomingManifest else { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.prompt = "Choose destination Git repository"
        guard picker.runModal() == .OK, let folder = picker.url else { return }
        do {
            plan = try WorkspaceHandoff.prepare(source: incomingManifest, destinationFolder: folder)
            destinationFolder = folder
            errorMessage = nil
            message = plan?.canOpen == true ? "Exact clean Git match. You can explicitly open it in VS Code." :
                "Handoff blocked due to Git differences. No files were modified."
        } catch { errorMessage = error.localizedDescription }
    }

    func continueOnThisMac() {
        guard let incomingManifest, let destinationFolder else { return }
        do {
            plan = try WorkspaceCommand.continueWithManifest(incomingManifest, destination: destinationFolder)
            message = plan?.canOpen == true ? "Requested VS Code to open the matching local repository." :
                "The destination changed; opening is blocked."
        } catch { errorMessage = error.localizedDescription }
    }

    func revokeAndDisconnect() {
        do {
            if let peerPublicKey { try trustStore.revoke(peerPublicKey) }
            disconnect()
        } catch {
            // Revocation already invalidates registered live channels even if
            // writing the Keychain fails; always disconnect on error.
            disconnect()
            errorMessage = "Trust revocation needs attention: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        transport?.stop()
        transport = nil
        coordinator = nil
        stopListening()
        connected = false
        pairingCode = nil
        peerPublicKey = nil
        incomingManifest = nil
        plan = nil
        destinationFolder = nil
    }
}

struct WorkspaceLANView: View {
    @StateObject private var model = WorkspaceLANModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Secure LAN Handoff · Experimental Beta").font(.title.bold())
                Text("No listener starts automatically. Both users must compare the same pairing code and approve independently. No source files or unsaved edits are synchronized.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                GroupBox("1 · Connect two Macs") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(model.listening ? "Stop listening" : "Accept connection for 2 minutes") {
                                if model.listening { model.stopListening() } else { model.startListening() }
                            }.disabled(model.connected)
                            Text("TCP port \(WorkspaceLANModel.portNumber)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField("Other Mac's LAN IP or hostname", text: $model.remoteHost)
                                .textFieldStyle(.roundedBorder)
                            Button("Connect") { model.connect() }
                                .disabled(model.connected || model.pairingCode != nil)
                        }
                        if let code = model.pairingCode {
                            Text("Pairing code: \(code)")
                                .font(.title2.weight(.semibold))
                                .textSelection(.enabled)
                            Text("Compare this exact code with the other Mac, by speaking to its user or checking both screens. Never approve an unexpected device.")
                                .foregroundStyle(.secondary)
                            Button("Codes match — approve this Mac") { model.approvePairing() }
                                .buttonStyle(.borderedProminent)
                        }
                        if model.connected {
                            Label("Mutually authenticated encrypted session", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            Button("Revoke this peer and disconnect") { model.revokeAndDisconnect() }
                                .foregroundStyle(.red)
                        }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("2 · Send Git workspace") {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Only a clean existing Git repository can send origin, branch and commit metadata. The receiver must review it before continuing.")
                            .foregroundStyle(.secondary)
                        Button("Choose repository and send encrypted manifest…") {
                            model.sendSelectedWorkspace()
                        }.disabled(!model.connected)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("3 · Review received workspace") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let received = model.incomingManifest {
                            Text("From: \(received.sourceDeviceName)").font(.headline)
                            Text("Origin: \(received.repository.origin)").textSelection(.enabled)
                            Text("Branch: \(received.repository.branch)")
                            Text("Commit: \(received.repository.headSHA)").font(.caption).textSelection(.enabled)
                            Button("Choose existing destination clone…") { model.inspectIncoming() }
                            if let plan = model.plan {
                                if plan.canOpen {
                                    Label("Repository verified and clean", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    ForEach(plan.blockers, id: \.self) { blocker in
                                        Label(blocker.rawValue, systemImage: "exclamationmark.triangle")
                                    }
                                }
                            }
                            Button("Continue in VS Code") { model.continueOnThisMac() }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.plan?.canOpen != true)
                        } else {
                            Text("No manifest received. Incoming data is never opened automatically.")
                                .foregroundStyle(.secondary)
                        }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = model.errorMessage {
                    Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                }
                Text(model.message).font(.callout)
                Button("Disconnect") { model.disconnect() }.buttonStyle(.bordered)
                Text("BETA · Not notarized or certified on two physical Macs. No Bonjour discovery; enter the destination LAN IP manually. Never expose this listener to untrusted networks.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 780, minHeight: 650)
        .onDisappear { model.disconnect() }
    }
}
#endif
