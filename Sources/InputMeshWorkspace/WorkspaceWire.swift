import Foundation

/// Data-only wire protocol used by Workspace Handoff, NOT the retired input
/// forwarding InputEnvelope. No plaintext manifest or command message exists.
public enum WorkspaceWireKind: String, Codable, Equatable, Sendable {
    case hello, proof, sealed, goodbye
}

public enum WorkspaceWireError: Error, Equatable {
    case invalidVersion, invalidPayload, oversizedPayload, oversizedChunk
    case invalidFrame, invalidTransition
}

public struct WorkspaceWireEnvelope: Codable, Equatable, Sendable {
    public static let version = 1
    public let version: Int
    public let kind: WorkspaceWireKind
    public let payload: Data

    public init(kind: WorkspaceWireKind, payload: Data) throws {
        self.version = Self.version
        self.kind = kind
        self.payload = payload
        try validate()
    }

    public func validate() throws {
        guard version == Self.version else { throw WorkspaceWireError.invalidVersion }
        switch kind {
        case .hello:
            guard !payload.isEmpty, payload.count <= 4096 else {
                throw WorkspaceWireError.invalidPayload
            }
        case .proof:
            guard !payload.isEmpty, payload.count <= 512 else {
                throw WorkspaceWireError.invalidPayload
            }
        case .sealed:
            guard payload.count >= 36, payload.count <= 65536 + 36 else {
                throw WorkspaceWireError.invalidPayload
            }
        case .goodbye:
            guard payload.isEmpty else { throw WorkspaceWireError.invalidPayload }
        }
    }
}

public enum WorkspaceWireCodec {
    /// JSON base64 envelope overhead plus a 64-KiB sealed message.
    public static let maxEncodedFrame = 96 * 1024
    /// Bounded single read; repeated small fragments are also size-limited.
    public static let maxReadChunk = 256 * 1024

    public static func encode(_ packet: WorkspaceWireEnvelope) throws -> Data {
        try packet.validate()
        let body = try JSONEncoder().encode(packet)
        guard !body.isEmpty, body.count <= maxEncodedFrame else {
            throw WorkspaceWireError.oversizedPayload
        }
        let n = UInt32(body.count)
        let prefix = Data([UInt8((n >> 24) & 255), UInt8((n >> 16) & 255),
                           UInt8((n >> 8) & 255), UInt8(n & 255)])
        return prefix + body
    }
}

public struct WorkspaceWireDecoder {
    private var buffer = Data()
    public init() {}

    /// Supports arbitrary TCP byte fragmentation and multiple frames per read.
    /// Invalid frames clear state; callers must close the connection on error.
    public mutating func append(_ chunk: Data) throws -> [WorkspaceWireEnvelope] {
        guard chunk.count <= WorkspaceWireCodec.maxReadChunk else {
            buffer.removeAll()
            throw WorkspaceWireError.oversizedChunk
        }
        buffer.append(chunk)
        var packets = [WorkspaceWireEnvelope]()
        while buffer.count >= 4 {
            let n = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard n > 0, n <= UInt32(WorkspaceWireCodec.maxEncodedFrame) else {
                buffer.removeAll()
                throw WorkspaceWireError.invalidFrame
            }
            let end = 4 + Int(n)
            guard buffer.count >= end else { break }
            let body = buffer.subdata(in: 4..<end)
            buffer.removeSubrange(0..<end)
            do {
                let message = try JSONDecoder().decode(WorkspaceWireEnvelope.self, from: body)
                try message.validate()
                packets.append(message)
            } catch {
                buffer.removeAll()
                throw WorkspaceWireError.invalidFrame
            }
        }
        guard buffer.count <= WorkspaceWireCodec.maxEncodedFrame + 4 else {
            buffer.removeAll()
            throw WorkspaceWireError.invalidFrame
        }
        return packets
    }
}

/// A conservative control-plane gate. The caller MUST cryptographically verify
/// peer proof and decrypt the remote consent ACK before invoking transitions.
/// Receiving a sealed envelope alone is NOT consent.
public struct WorkspaceWirePolicy {
    public enum Phase: String, Sendable {
        case awaitingHello, awaitingProof, awaitingVerifiedProof
        case awaitingLocalApproval, awaitingEncryptedPeerApproval
        case ready, closed
    }

    public private(set) var phase: Phase = .awaitingHello
    public init() {}
    public var maySendWorkspace: Bool { phase == .ready }

    public mutating func receive(_ kind: WorkspaceWireKind) throws {
        if kind == .goodbye { phase = .closed; return }
        switch phase {
        case .awaitingHello:
            guard kind == .hello else { throw WorkspaceWireError.invalidTransition }
            phase = .awaitingProof
        case .awaitingProof:
            guard kind == .proof else { throw WorkspaceWireError.invalidTransition }
            phase = .awaitingVerifiedProof
        case .awaitingEncryptedPeerApproval, .ready:
            guard kind == .sealed else { throw WorkspaceWireError.invalidTransition }
        case .awaitingVerifiedProof, .awaitingLocalApproval, .closed:
            throw WorkspaceWireError.invalidTransition
        }
    }

    /// Call only after verifying the transcript-bound Ed25519 signature.
    public mutating func markPeerProofVerified() throws {
        guard phase == .awaitingVerifiedProof else { throw WorkspaceWireError.invalidTransition }
        phase = .awaitingLocalApproval
    }

    /// Call only after this Mac's user matched the SAS on both displays.
    public mutating func markLocalUserApproved() throws {
        guard phase == .awaitingLocalApproval else { throw WorkspaceWireError.invalidTransition }
        phase = .awaitingEncryptedPeerApproval
    }

    /// Call only after opening and validating a peer-signed encrypted ACK;
    /// the app layer must check expected session ID and trust revocation.
    public mutating func markEncryptedPeerConsentVerified() throws {
        guard phase == .awaitingEncryptedPeerApproval else { throw WorkspaceWireError.invalidTransition }
        phase = .ready
    }

    public mutating func close() { phase = .closed }
}
