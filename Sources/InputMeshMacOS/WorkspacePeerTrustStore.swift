#if os(macOS)
import Foundation
import Security

/// Persist *public* peer identity keys after explicit SAS verification.
/// There is no unauthenticated auto-trust / TOFU or network permission.
public protocol WorkspacePeerTrustPersistence {
    func load() throws -> [Data]
    func save(_ keys: [Data]) throws
}

public struct WorkspaceKeychainPeerPersistence: WorkspacePeerTrustPersistence {
    public init() {}

    private var query: [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "dev.inputmesh.workspace.trusted-peers.v1",
        kSecAttrAccount as String: "default"
    ] }

    public func load() throws -> [Data] {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw MacIdentityError.keychain(status) }
        guard let bytes = result as? Data,
              let keys = try? JSONDecoder().decode([Data].self, from: bytes),
              keys.count <= 128,
              keys.allSatisfy({ $0.count == 32 }),
              Set(keys).count == keys.count else { throw MacIdentityError.corruptStoredKey }
        return keys
    }

    public func save(_ keys: [Data]) throws {
        guard keys.count <= 128, keys.allSatisfy({ $0.count == 32 }),
              Set(keys).count == keys.count else { throw WorkspaceSessionError.invalidPeer }
        let payload = try JSONEncoder().encode(keys)
        let status = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: payload] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw MacIdentityError.keychain(status) }
        var attributes = query
        attributes[kSecValueData as String] = payload
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let insert = SecItemAdd(attributes as CFDictionary, nil)
        guard insert == errSecSuccess else { throw MacIdentityError.keychain(insert) }
    }
}

private final class WorkspaceWeakChannel {
    weak var channel: WorkspaceEncryptedChannel?
    init(_ channel: WorkspaceEncryptedChannel) { self.channel = channel }
}

/// Controls which verified signing identities can be remembered on the local
/// Mac. Revocation fails closed for every channel created by this registry.
public final class WorkspacePeerTrustStore {
    private let persistence: WorkspacePeerTrustPersistence
    private let mutex = NSLock()
    private var active: [Data: [WorkspaceWeakChannel]] = [:]

    public init(persistence: WorkspacePeerTrustPersistence = WorkspaceKeychainPeerPersistence()) {
        self.persistence = persistence
    }

    public func isTrusted(_ publicKey: Data) throws -> Bool {
        guard publicKey.count == 32 else { throw WorkspaceSessionError.invalidPeer }
        mutex.lock(); defer { mutex.unlock() }
        return try persistence.load().contains(publicKey)
    }

    /// Only call after *both Macs* displayed matching SAS and this user
    /// explicitly entered it; remote acceptance still needs an encrypted ACK.
    // Internal test/diagnostic primitive. Production coordinator records trust
    // ONLY after authenticating the other Mac's encrypted consent response.
    func approve(_ pending: WorkspaceSessionPending,
                        enteredCode: String) throws -> WorkspaceEncryptedChannel {
        mutex.lock(); defer { mutex.unlock() }
        guard enteredCode == pending.comparisonCode else {
            throw WorkspaceSessionError.pairingNotConfirmed
        }
        let peer = pending.peerIdentity
        guard peer.count == 32 else { throw WorkspaceSessionError.invalidPeer }
        var trusted = try persistence.load()
        if !trusted.contains(peer) {
            guard trusted.count < 128 else { throw WorkspaceSessionError.invalidPeer }
            trusted.append(peer)
        }
        let channel = try pending.activateAfterUserConfirmation(enteredCode: enteredCode)
        do { try persistence.save(trusted) }
        catch {
            channel.invalidate()
            throw error
        }
        active[peer, default: []].removeAll { $0.channel == nil }
        active[peer, default: []].append(WorkspaceWeakChannel(channel))
        return channel
    }

    /// Called by WorkspaceConsentCoordinator only after this Mac approved the
    /// SAS and the peer's encrypted acceptance was decrypted and validated.
    /// Keeps no trusted identity if persistence fails.
    func registerMutualConsent(peerIdentity: Data, channel: WorkspaceEncryptedChannel) throws {
        mutex.lock(); defer { mutex.unlock() }
        guard peerIdentity.count == 32 else {
            channel.invalidate()
            throw WorkspaceSessionError.invalidPeer
        }
        do {
            var trusted = try persistence.load()
            if !trusted.contains(peerIdentity) {
                guard trusted.count < 128 else { throw WorkspaceSessionError.invalidPeer }
                trusted.append(peerIdentity)
            }
            try persistence.save(trusted)
            active[peerIdentity, default: []].removeAll { $0.channel == nil }
            active[peerIdentity, default: []].append(WorkspaceWeakChannel(channel))
        } catch {
            channel.invalidate()
            throw error
        }
    }

    /// Invalidate live channels even if Keychain write fails. Caller must also
    /// cancel the owning NWConnection and surface persistence errors to user.
    public func revoke(_ publicKey: Data) throws {
        guard publicKey.count == 32 else { throw WorkspaceSessionError.invalidPeer }
        mutex.lock(); defer { mutex.unlock() }
        for ref in active.removeValue(forKey: publicKey) ?? [] {
            ref.channel?.invalidate()
        }
        var keys = try persistence.load()
        keys.removeAll { $0 == publicKey }
        try persistence.save(keys)
    }
}
#endif
