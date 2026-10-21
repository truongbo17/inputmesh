#if os(macOS)
import Foundation
import InputMeshWorkspace

/// A single authenticated workspace session. All calls must be serialized by
/// the owning connection's event queue; this type never starts a listener.
public enum WorkspaceConsentError: Error, Equatable {
    case notStarted, invalidState, invalidConsent, revokedPeer
}

public enum WorkspaceConsentEvent: Equatable {
    case pairingCode(String)
    case ready
    case manifest(WorkspaceManifest)
    case closed
}

public struct WorkspaceConsentTransition {
    public let outgoing: [WorkspaceWireEnvelope]
    public let event: WorkspaceConsentEvent?

    public init(outgoing: [WorkspaceWireEnvelope] = [], event: WorkspaceConsentEvent? = nil) {
        self.outgoing = outgoing
        self.event = event
    }
}

/// Orchestrates cryptographic primitives with the portable wire-policy gate.
///
/// Both machines must verify the same SAS out of band and approve locally.
/// A signed transcript alone NEVER trusts a peer. Local approval sends an
/// encrypted ACK; ONLY a valid decrypted ACK from the other machine allows
/// a manifest and persists that peer in Keychain.
public final class WorkspaceConsentCoordinator {
    private static let approval = Data("inputmesh/workspace/consent-accepted/v1".utf8)

    private let handshake: WorkspaceSessionHandshake
    private let store: WorkspacePeerTrustStore
    private var policy = WorkspaceWirePolicy()
    private var peerHello: WorkspaceSessionHello?
    private var pending: WorkspaceSessionPending?
    private var channel: WorkspaceEncryptedChannel?
    private var queuedPeerAcceptance: Data?
    private var started = false

    public init(identity: MacDeviceIdentity, role: WorkspaceSessionRole,
                trustStore: WorkspacePeerTrustStore = WorkspacePeerTrustStore()) throws {
        self.handshake = try WorkspaceSessionHandshake(identity: identity, role: role)
        self.store = trustStore
    }

    public var phase: WorkspaceWirePolicy.Phase { policy.phase }
    public var isReady: Bool { policy.maySendWorkspace }
    /// Exposes the peer signing identity ONLY after mutual encrypted consent.
    public var verifiedPeerPublicKey: Data? {
        isReady ? peerHello?.identityPublicKey : nil
    }

    public func begin() throws -> WorkspaceWireEnvelope {
        guard !started, phase == .awaitingHello else { throw WorkspaceConsentError.invalidState }
        started = true
        return try WorkspaceWireEnvelope(kind: .hello,
                                          payload: JSONEncoder().encode(handshake.hello))
    }

    public func receive(_ message: WorkspaceWireEnvelope) throws -> WorkspaceConsentTransition {
        guard started else { throw WorkspaceConsentError.notStarted }
        guard phase != .closed else { throw WorkspaceConsentError.invalidState }
        do {
            try message.validate()
            switch message.kind {
            case .hello:
                try policy.receive(.hello)
                let peer = try JSONDecoder().decode(WorkspaceSessionHello.self, from: message.payload)
                try peer.validate()
                peerHello = peer
                let proof = try handshake.makeProof(for: peer)
                return WorkspaceConsentTransition(outgoing: [
                    try WorkspaceWireEnvelope(kind: .proof, payload: proof)
                ])

            case .proof:
                try policy.receive(.proof)
                guard let peerHello else { throw WorkspaceConsentError.invalidState }
                let result = try handshake.verifyAndPrepare(peer: peerHello, proof: message.payload)
                try policy.markPeerProofVerified()
                pending = result
                return WorkspaceConsentTransition(event: .pairingCode(result.comparisonCode))

            case .sealed:
                // The remote Mac may approve before this user has clicked.
                // Keep at most one bounded opaque packet, then decrypt only
                // after local approval. No early manifest or trust is granted.
                if phase == .awaitingLocalApproval {
                    guard queuedPeerAcceptance == nil else { throw WorkspaceConsentError.invalidState }
                    queuedPeerAcceptance = message.payload
                    return WorkspaceConsentTransition()
                }
                return try handleEncrypted(message)

            case .goodbye:
                close()
                return WorkspaceConsentTransition(event: .closed)
            }
        } catch {
            close()
            throw error
        }
    }

    /// This is invoked only by an explicit human action after comparing codes
    /// shown independently on the two devices.
    public func confirmPairing(code: String) throws -> WorkspaceConsentTransition {
        guard started, phase == .awaitingLocalApproval, let pending else {
            throw WorkspaceConsentError.invalidState
        }
        do {
            // Incorrect code does not activate a channel or persist trust.
            let activated = try pending.activateAfterUserConfirmation(enteredCode: code)
            channel = activated
            try policy.markLocalUserApproved()
            let encryptedApproval = try activated.seal(Self.approval)
            let outgoing = try WorkspaceWireEnvelope(kind: .sealed, payload: encryptedApproval)
            self.pending = nil

            if let early = queuedPeerAcceptance {
                queuedPeerAcceptance = nil
                let inbound = try WorkspaceWireEnvelope(kind: .sealed, payload: early)
                let result = try handleEncrypted(inbound)
                return WorkspaceConsentTransition(outgoing: [outgoing], event: result.event)
            }
            return WorkspaceConsentTransition(outgoing: [outgoing])
        } catch WorkspaceSessionError.pairingNotConfirmed {
            throw WorkspaceSessionError.pairingNotConfirmed
        } catch {
            close()
            throw error
        }
    }

    /// Returns inert validated metadata; it never opens an editor, executes
    /// commands, rewrites a repository or accepts instructions from the peer.
    public func sendManifest(_ manifest: WorkspaceManifest) throws -> WorkspaceWireEnvelope {
        guard policy.maySendWorkspace, let channel, let peerHello else {
            throw WorkspaceConsentError.invalidState
        }
        guard try store.isTrusted(peerHello.identityPublicKey) else {
            close()
            throw WorkspaceConsentError.revokedPeer
        }
        return try WorkspaceWireEnvelope(kind: .sealed, payload:
            channel.seal(manifest.encodedData()))
    }

    public func close() {
        channel?.invalidate()
        channel = nil
        pending = nil
        queuedPeerAcceptance = nil
        policy.close()
    }

    private func handleEncrypted(_ message: WorkspaceWireEnvelope) throws -> WorkspaceConsentTransition {
        guard let channel, let peerHello else { throw WorkspaceConsentError.invalidState }
        try policy.receive(.sealed)
        let plaintext = try channel.open(message.payload)

        if phase == .awaitingEncryptedPeerApproval {
            guard plaintext == Self.approval else { throw WorkspaceConsentError.invalidConsent }
            try store.registerMutualConsent(peerIdentity: peerHello.identityPublicKey, channel: channel)
            try policy.markEncryptedPeerConsentVerified()
            return WorkspaceConsentTransition(event: .ready)
        }

        guard policy.maySendWorkspace else { throw WorkspaceConsentError.invalidState }
        guard try store.isTrusted(peerHello.identityPublicKey) else {
            throw WorkspaceConsentError.revokedPeer
        }
        return WorkspaceConsentTransition(event: .manifest(try WorkspaceManifest.decode(plaintext)))
    }
}
#endif
