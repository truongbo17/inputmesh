#if os(macOS)
import CryptoKit
import Foundation
import Security

/// Cryptographic core only. It does not open a socket, accept remote work or
/// authorize any peer without an explicit verified SAS and two-way consent.
public enum WorkspaceSessionError: Error, Equatable {
    case malformedHello, incorrectRole, badSignature, invalidPeer
    case pairingNotConfirmed, replay, invalidFrame, oversizedFrame, exhausted, entropyFailure
}

public enum WorkspaceSessionRole: String, Codable {
    case initiator, responder
}

public struct WorkspaceSessionHello: Codable, Equatable {
    public let version: Int
    public let role: WorkspaceSessionRole
    public let identityPublicKey: Data
    public let ephemeralPublicKey: Data
    public let nonce: Data

    public func validate() throws {
        guard version == 1, identityPublicKey.count == 32,
              ephemeralPublicKey.count == 32, nonce.count == 32 else {
            throw WorkspaceSessionError.malformedHello
        }
    }
}

/// Each fresh connection MUST create a new handshake. Identity Ed25519 signatures
/// authenticate the complete X25519 transcript and both nonce/role commitments.
public final class WorkspaceSessionHandshake {
    private let identity: MacDeviceIdentity
    private let agreement = Curve25519.KeyAgreement.PrivateKey()
    public let hello: WorkspaceSessionHello
    private var completed = false
    private let handshakeLock = NSLock()

    public init(identity: MacDeviceIdentity, role: WorkspaceSessionRole) throws {
        self.identity = identity
        var nonce = Data(count: 32)
        let result: OSStatus = nonce.withUnsafeMutableBytes { ptr in
            guard let pointer = ptr.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, 32, pointer)
        }
        guard result == errSecSuccess else { throw WorkspaceSessionError.entropyFailure }
        self.hello = WorkspaceSessionHello(version: 1, role: role,
            identityPublicKey: identity.publicKey,
            ephemeralPublicKey: agreement.publicKey.rawRepresentation, nonce: nonce)
    }

    /// The calling transport serializes this proof only after both hellos arrive.
    public func makeProof(for peer: WorkspaceSessionHello) throws -> Data {
        try identity.sign(challenge: Self.digest(local: hello, peer: peer))
    }

    public func verifyAndPrepare(peer: WorkspaceSessionHello, proof: Data) throws -> WorkspaceSessionPending {
        handshakeLock.lock()
        defer { handshakeLock.unlock() }
        guard !completed else { throw WorkspaceSessionError.replay }
        let transcript = try Self.digest(local: hello, peer: peer)
        guard MacDeviceIdentity.verify(publicKey: peer.identityPublicKey,
                                       challenge: transcript, signature: proof) else {
            throw WorkspaceSessionError.badSignature
        }
        let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peer.ephemeralPublicKey)
        let secret = try agreement.sharedSecretFromKeyAgreement(with: publicKey)
        let i2r = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: transcript,
            sharedInfo: Data("inputmesh/workspace/i2r/v1".utf8), outputByteCount: 32)
        let r2i = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: transcript,
            sharedInfo: Data("inputmesh/workspace/r2i/v1".utf8), outputByteCount: 32)
        let hex = SHA256.hash(data: Data("inputmesh/workspace/sas/v1".utf8) + transcript)
            .prefix(5).map { String(format: "%02X", $0) }.joined()
        completed = true
        return WorkspaceSessionPending(peerIdentity: peer.identityPublicKey,
            comparisonCode: String(hex.prefix(5)) + "-" + String(hex.suffix(5)),
            sendKey: hello.role == .initiator ? i2r : r2i,
            receiveKey: hello.role == .initiator ? r2i : i2r,
            transcript: transcript, sender: hello.role.rawValue, receiver: peer.role.rawValue)
    }

    private static func digest(local: WorkspaceSessionHello, peer: WorkspaceSessionHello) throws -> Data {
        try local.validate()
        try peer.validate()
        guard local.role != peer.role else { throw WorkspaceSessionError.incorrectRole }
        guard local.identityPublicKey != peer.identityPublicKey,
              local.ephemeralPublicKey != peer.ephemeralPublicKey,
              local.nonce != peer.nonce else { throw WorkspaceSessionError.invalidPeer }
        let a = local.role == .initiator ? local : peer
        let b = local.role == .responder ? local : peer
        let transcript = Data("inputmesh/workspace/handshake/v1\0".utf8)
            + a.identityPublicKey + b.identityPublicKey
            + a.ephemeralPublicKey + b.ephemeralPublicKey + a.nonce + b.nonce
        return Data(SHA256.hash(data: transcript))
    }
}

/// Local confirmation is mandatory. Higher-level transport must exchange a
/// separate encrypted ACCEPT message from BOTH users before any workspace data.
public final class WorkspaceSessionPending {
    public let peerIdentity: Data
    public let comparisonCode: String
    fileprivate let sendKey: SymmetricKey
    fileprivate let receiveKey: SymmetricKey
    fileprivate let transcript: Data
    fileprivate let sender: String
    fileprivate let receiver: String
    private var activated = false
    private let activationLock = NSLock()

    fileprivate init(peerIdentity: Data, comparisonCode: String, sendKey: SymmetricKey,
                     receiveKey: SymmetricKey, transcript: Data, sender: String, receiver: String) {
        self.peerIdentity = peerIdentity
        self.comparisonCode = comparisonCode
        self.sendKey = sendKey
        self.receiveKey = receiveKey
        self.transcript = transcript
        self.sender = sender
        self.receiver = receiver
    }

    public func activateAfterUserConfirmation(enteredCode: String) throws -> WorkspaceEncryptedChannel {
        activationLock.lock()
        defer { activationLock.unlock() }
        guard enteredCode == comparisonCode else { throw WorkspaceSessionError.pairingNotConfirmed }
        guard !activated else { throw WorkspaceSessionError.replay }
        activated = true
        return WorkspaceEncryptedChannel(sendKey: sendKey, receiveKey: receiveKey,
            transcript: transcript, sender: sender, receiver: receiver)
    }
}

/// Single-use, strict-order authenticated encryption. Frames are bounded and
/// sequence numbers may not repeat; a new handshake is required on reconnect.
public final class WorkspaceEncryptedChannel {
    public static let maxPayload = 64 * 1024
    private let sendKey: SymmetricKey
    private let receiveKey: SymmetricKey
    private let transcript: Data
    private let sender: String
    private let receiver: String
    private var sendSequence: UInt64 = 0
    private var receiveSequence: UInt64 = 0
    private let mutex = NSLock()

    fileprivate init(sendKey: SymmetricKey, receiveKey: SymmetricKey,
                     transcript: Data, sender: String, receiver: String) {
        self.sendKey = sendKey; self.receiveKey = receiveKey
        self.transcript = transcript; self.sender = sender; self.receiver = receiver
    }

    public func seal(_ data: Data) throws -> Data {
        mutex.lock(); defer { mutex.unlock() }
        guard data.count <= Self.maxPayload else { throw WorkspaceSessionError.oversizedFrame }
        guard sendSequence < UInt64.max else { throw WorkspaceSessionError.exhausted }
        let n = sendSequence
        let nonce = try ChaChaPoly.Nonce(data: Self.nonce(n))
        let box = try ChaChaPoly.seal(data, using: sendKey, nonce: nonce,
            authenticating: associatedData(n, direction: sender))
        sendSequence += 1
        return Self.number(n) + box.combined
    }

    public func open(_ frame: Data) throws -> Data {
        mutex.lock(); defer { mutex.unlock() }
        guard frame.count >= 8 + 12 + 16 else { throw WorkspaceSessionError.invalidFrame }
        guard frame.count <= Self.maxPayload + 8 + 12 + 16 else {
            throw WorkspaceSessionError.oversizedFrame
        }
        let n = frame.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard n == receiveSequence else { throw WorkspaceSessionError.replay }
        guard receiveSequence < UInt64.max else { throw WorkspaceSessionError.exhausted }
        let combined = Data(frame.dropFirst(8))
        guard Data(combined.prefix(12)) == Self.nonce(n) else {
            throw WorkspaceSessionError.invalidFrame
        }
        let box = try ChaChaPoly.SealedBox(combined: combined)
        let data = try ChaChaPoly.open(box, using: receiveKey,
            authenticating: associatedData(n, direction: receiver))
        receiveSequence += 1
        return data
    }

    private func associatedData(_ n: UInt64, direction: String) -> Data {
        transcript + Data("inputmesh/workspace/message/v1\0".utf8)
            + Data(direction.utf8) + Self.number(n)
    }

    private static func number(_ n: UInt64) -> Data {
        var value = n.bigEndian
        return withUnsafeBytes(of: &value) { Data($0) }
    }
    private static func nonce(_ n: UInt64) -> Data {
        Data(repeating: 0, count: 4) + number(n)
    }
}
#endif
