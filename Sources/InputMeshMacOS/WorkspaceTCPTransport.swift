#if os(macOS)
import Foundation
import Network
import InputMeshWorkspace

public enum WorkspaceTCPError: Error {
    case closed, timeout, incompleteFrame
}

/// Single-session Network.framework TCP adapter. The injected authenticated
/// coordinator owns all security decisions; this class does not create a
/// listener, announce Bonjour services or approve peers automatically.
///
/// All coordinator calls are serialized on a private dispatch queue.
/// Callbacks also execute on that queue; UI integrations MUST dispatch to main.
public final class WorkspaceTCPTransport {
    private let connection: NWConnection
    private let coordinator: WorkspaceConsentCoordinator
    private let queue: DispatchQueue
    private let onEvent: (WorkspaceConsentEvent) -> Void
    private let onError: (Error) -> Void
    private var decoder = WorkspaceWireDecoder()
    private var started = false
    private var stopped = false
    private var handshakeTimer: DispatchSourceTimer?

    public init(connection: NWConnection, coordinator: WorkspaceConsentCoordinator,
                onEvent: @escaping (WorkspaceConsentEvent) -> Void,
                onError: @escaping (Error) -> Void) {
        self.connection = connection
        self.coordinator = coordinator
        self.queue = DispatchQueue(label: "dev.inputmesh.workspace.tcp.\(UUID().uuidString)")
        self.onEvent = onEvent
        self.onError = onError
    }

    /// The caller initiates the connection or accepts it using an explicitly
    /// enabled NWListener. No background listener is created here.
    public func start() {
        queue.async { [weak self] in
            guard let self, !self.started, !self.stopped else { return }
            self.started = true
            self.connection.stateUpdateHandler = { [weak self] state in
                guard let self, !self.stopped else { return }
                switch state {
                case .ready:
                    self.beginHandshake()
                case .failed(let error), .waiting(let error):
                    self.finish(error)
                case .cancelled:
                    self.finish(WorkspaceTCPError.closed)
                default:
                    break
                }
            }
            self.connection.start(queue: self.queue)
        }
    }

    /// Must be invoked in response to a verified code displayed to the user
    /// on both devices; the production UI must never auto-confirm.
    public func approveMatchingCode(_ code: String) {
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            do {
                let transition = try self.coordinator.confirmPairing(code: code)
                try self.deliver(transition)
            } catch {
                self.finish(error)
            }
        }
    }

    public func sendManifest(_ manifest: WorkspaceManifest) {
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            do {
                let packet = try self.coordinator.sendManifest(manifest)
                try self.send(packet)
            } catch {
                self.finish(error)
            }
        }
    }

    /// Manual disconnection is idempotent, and invalidates the encrypted
    /// channel even when the TCP connection is stuck or half-closed.
    public func stop() {
        queue.async { [weak self] in self?.finish(nil) }
    }

    private func beginHandshake() {
        do {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + .seconds(60))
            timer.setEventHandler { [weak self] in self?.finish(WorkspaceTCPError.timeout) }
            handshakeTimer = timer
            timer.resume()
            try send(coordinator.begin())
            receiveNext()
        } catch {
            finish(error)
        }
    }

    private func receiveNext() {
        guard !stopped else { return }
        // The framing decoder rejects invalid length headers and buffers at
        // most one bounded partial frame; no unbounded socket read is made.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self, !self.stopped else { return }
            if let error { self.finish(error); return }
            do {
                if let data, !data.isEmpty {
                    for message in try self.decoder.append(data) {
                        let transition = try self.coordinator.receive(message)
                        try self.deliver(transition)
                    }
                }
                if isComplete {
                    self.finish(WorkspaceTCPError.closed)
                } else {
                    self.receiveNext()
                }
            } catch {
                self.finish(error)
            }
        }
    }

    private func deliver(_ transition: WorkspaceConsentTransition) throws {
        for packet in transition.outgoing { try send(packet) }
        if let event = transition.event {
            if case .ready = event {
                handshakeTimer?.cancel()
                handshakeTimer = nil
            }
            onEvent(event)
            if case .closed = event {
                // The peer has deliberately ended this session. Do not leave
                // an authenticated-but-dead TCP connection accepting bytes.
                finish(nil)
            }
        }
    }

    private func send(_ packet: WorkspaceWireEnvelope) throws {
        guard !stopped else { throw WorkspaceTCPError.closed }
        let frame = try WorkspaceWireCodec.encode(packet)
        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            guard let self, let error else { return }
            self.queue.async { self.finish(error) }
        })
    }

    private func finish(_ error: Error?) {
        guard !stopped else { return }
        stopped = true
        handshakeTimer?.cancel()
        handshakeTimer = nil
        coordinator.close()
        connection.cancel()
        if let error { onError(error) }
    }
}
#endif
