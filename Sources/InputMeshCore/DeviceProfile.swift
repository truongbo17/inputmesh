import Foundation

/// Wire-level OS identity. Never use the platform string to select trusted peers;
/// cryptographic device identity and explicit pairing are separate concerns.
public enum HostPlatform: String, Codable, CaseIterable, Sendable {
    case macOS
    case windows
    case linux
}

/// Capabilities are independently negotiated rather than inferred from operating system.
/// Unsupported features must not silently fall back to privileged input injection.
public enum InputCapability: String, Codable, CaseIterable, Hashable, Sendable {
    case captureKeyboard
    case capturePointer
    case injectKeyboard
    case injectPointer
    case enumerateDisplays
    case relativePointer
    case securePairing
}

public struct DeviceProfile: Codable, Equatable, Sendable {
    public let id: String
    public let platform: HostPlatform
    public let protocolVersion: UInt16
    public let capabilities: Set<InputCapability>

    public init(id: String, platform: HostPlatform,
                protocolVersion: UInt16 = InputEnvelope.currentVersion,
                capabilities: Set<InputCapability>) {
        self.id = id
        self.platform = platform
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
    }
}

public enum PeerCompatibilityError: Error, Equatable {
    case invalidDeviceIdentity
    case incompatibleVersion
    case missingCapabilities(Set<InputCapability>)
}

public enum PeerCompatibility {
    /// Only a protocol/capability check, NOT a pairing, trust or access decision.
    public static func require(_ required: Set<InputCapability>, from peer: DeviceProfile) throws {
        guard !peer.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PeerCompatibilityError.invalidDeviceIdentity }
        guard peer.protocolVersion == InputEnvelope.currentVersion else {
            throw PeerCompatibilityError.incompatibleVersion
        }
        let missing = required.subtracting(peer.capabilities)
        guard missing.isEmpty else { throw PeerCompatibilityError.missingCapabilities(missing) }
    }
}
