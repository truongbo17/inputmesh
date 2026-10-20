#if os(macOS)
import CryptoKit
import Foundation
import Security

/// Device identity for a future authenticated handoff transport. No network
/// connection is opened by this class and it does not grant any peer trust.
public struct MacDeviceIdentity {
    private let privateKey: Curve25519.Signing.PrivateKey

    public init() {
        // Ephemeral identities exist for testing signed challenges only.
        self.privateKey = Curve25519.Signing.PrivateKey()
    }

    private init(key: Curve25519.Signing.PrivateKey) { self.privateKey = key }

    public var publicKey: Data { privateKey.publicKey.rawRepresentation }
    public var fingerprint: String { SHA256.hash(data: publicKey).map { String(format: "%02x", $0) }.joined() }

    /// Challenge/response must still be bound to an authenticated, encrypted
    /// channel before it can be used for production device pairing.
    public func sign(challenge: Data) throws -> Data {
        guard challenge.count >= 32 && challenge.count <= 64 else { throw MacIdentityError.invalidChallenge }
        return try privateKey.signature(for: Self.challengePayload(challenge, publicKey))
    }

    public static func verify(publicKey: Data, challenge: Data, signature: Data) -> Bool {
        guard publicKey.count == 32, challenge.count >= 32 && challenge.count <= 64,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey) else { return false }
        return key.isValidSignature(signature, for: challengePayload(challenge, publicKey))
    }

    private static func challengePayload(_ nonce: Data, _ senderKey: Data) -> Data {
        Data("inputmesh/workspace-pairing/v1\u{0}".utf8) + senderKey + nonce
    }

    /// A short comparison aid, NOT an encryption key or proof of authenticity.
    /// Both devices must display the same code using a trusted out-of-band channel.
    public static func comparisonCode(localPublicKey: Data, remotePublicKey: Data) throws -> String {
        guard localPublicKey.count == 32, remotePublicKey.count == 32,
              localPublicKey != remotePublicKey else { throw MacIdentityError.invalidPeer }
        let sorted = [localPublicKey, remotePublicKey].sorted { $0.lexicographicallyPrecedes($1) }
        let digest = SHA256.hash(data: Data("inputmesh/sas/v1".utf8) + sorted[0] + sorted[1])
        let code = digest.prefix(5).map { String(format: "%02X", $0) }.joined()
        return String(code.prefix(5)) + "-" + String(code.suffix(5))
    }

    /// Stored device private keys never leave this Mac through the API.
    /// Not called automatically in CI: access requires a real user's Keychain.
    public static func loadOrCreateInKeychain() throws -> MacDeviceIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.inputmesh.workspace.identity.v1",
            kSecAttrAccount as String: "default",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            guard let data = item as? Data, let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) else {
                throw MacIdentityError.corruptStoredKey
            }
            return MacDeviceIdentity(key: key)
        }
        guard status == errSecItemNotFound else { throw MacIdentityError.keychain(status) }
        let identity = MacDeviceIdentity()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.inputmesh.workspace.identity.v1",
            kSecAttrAccount as String: "default",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: identity.privateKey.rawRepresentation
        ]
        let inserted = SecItemAdd(attributes as CFDictionary, nil)
        if inserted == errSecDuplicateItem { return try loadOrCreateInKeychain() }
        guard inserted == errSecSuccess else { throw MacIdentityError.keychain(inserted) }
        return identity
    }
}

public enum MacIdentityError: Error, Equatable {
    case invalidChallenge
    case invalidPeer
    case corruptStoredKey
    case keychain(OSStatus)
}
#endif
