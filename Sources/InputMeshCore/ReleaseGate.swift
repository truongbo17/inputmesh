import Foundation

/// Production gates for the **Workspace Handoff** product, not the retired
/// cross-computer cursor / Universal Control experiment.
public enum WorkspaceReleaseGate: String, CaseIterable, Codable, Sendable {
    case linuxCoreCI
    case macOSArm64CI
    case macOSIntelCI
    case authenticatedTwoMacPairing
    case encryptedMutualConsent
    case manifestAndConflictRegression
    case peerRevocationVerified
    case physicalTwoMacHandoff
    case networkSleepWakeRecovery
    case nativeUIAccessibilityReview
    case independentSecurityAssessment
    case developerIDNotarization
    case supportedOSRuntimeMatrix

    public var description: String {
        switch self {
        case .linuxCoreCI: "Linux portable tests"
        case .macOSArm64CI: "Apple Silicon build / test / package"
        case .macOSIntelCI: "Intel build / test / package"
        case .authenticatedTwoMacPairing: "Verified pairing between two physical Macs"
        case .encryptedMutualConsent: "Encrypted bilateral consent and session authentication"
        case .manifestAndConflictRegression: "Git manifest integrity and conflict regression"
        case .peerRevocationVerified: "Peer revocation and live-session invalidation"
        case .physicalTwoMacHandoff: "Physical Mac A to Mac B workspace handoff"
        case .networkSleepWakeRecovery: "Wi-Fi loss, reconnect, sleep/wake and crash recovery"
        case .nativeUIAccessibilityReview: "Native screenshot and accessibility QA"
        case .independentSecurityAssessment: "Independent security review"
        case .developerIDNotarization: "Apple Developer ID signing and notarization"
        case .supportedOSRuntimeMatrix: "Runtime compatibility on declared macOS versions"
        }
    }
}

public enum ReleaseEvidenceError: Error, Equatable {
    case invalidEvidenceReference, invalidVerifier
}

/// Human/CI verified references are mandatory. A boolean claiming a gate is
/// true is not sufficient evidence. Verification still requires actual review:
/// this data structure alone is NOT a notarization or independent audit.
public struct ReleaseAttestation: Codable, Equatable, Sendable {
    public let evidenceURL: String
    public let verifiedBy: String
    public let recordedAt: Date

    public init(evidenceURL: String, verifiedBy: String, recordedAt: Date = Date()) throws {
        self.evidenceURL = evidenceURL
        self.verifiedBy = verifiedBy
        self.recordedAt = recordedAt
        try validate()
    }

    public func validate() throws {
        guard evidenceURL.utf8.count <= 2048,
              let uri = URLComponents(string: evidenceURL), uri.scheme == "https",
              let host = uri.host, !host.isEmpty, uri.user == nil, uri.password == nil else {
            throw ReleaseEvidenceError.invalidEvidenceReference
        }
        guard !verifiedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              verifiedBy.utf8.count <= 128 else { throw ReleaseEvidenceError.invalidVerifier }
    }
}

/// Schema 2 deliberately fails closed when reading older (cursor-oriented)
/// status reports. The CI suite tests logic using simulated attestations;
/// those tests do NOT create any production QA evidence.
public struct ReleaseEvidence: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public let schemaVersion: Int
    public private(set) var attestations: [WorkspaceReleaseGate: ReleaseAttestation]

    public init() {
        self.schemaVersion = Self.currentVersion
        self.attestations = [:]
    }

    public mutating func record(_ gate: WorkspaceReleaseGate, with evidence: ReleaseAttestation) throws {
        try evidence.validate()
        guard schemaVersion == Self.currentVersion else { throw ReleaseEvidenceError.invalidEvidenceReference }
        attestations[gate] = evidence
    }

    public var stableEligible: Bool {
        schemaVersion == Self.currentVersion &&
            WorkspaceReleaseGate.allCases.allSatisfy { gate in
                guard let evidence = attestations[gate] else { return false }
                return (try? evidence.validate()) != nil
            }
    }

    public var outstanding: [String] {
        guard schemaVersion == Self.currentVersion else { return ["Unsupported release evidence schema"] }
        return WorkspaceReleaseGate.allCases.filter { gate in
            guard let evidence = attestations[gate] else { return true }
            return (try? evidence.validate()) == nil
        }.map(\.description)
    }
}
