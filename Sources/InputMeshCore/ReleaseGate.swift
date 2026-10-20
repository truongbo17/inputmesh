import Foundation

/// A deterministic, auditable definition of what 'stable release' means.
/// Automated CI is necessary but not sufficient for privileged macOS input control.
public struct ReleaseEvidence: Codable, Equatable, Sendable {
    public var linuxUnitTests: Bool
    public var macOSArm64BuildTests: Bool
    public var macOSIntelBuildTests: Bool
    public var pairedPhysicalMacHandoff: Bool
    public var disconnectFailsOpen: Bool
    public var permissionRevocationFailsOpen: Bool
    public var authenticatedEncryptedTransport: Bool
    public var signedAndNotarized: Bool
    public var uiAccessibilityReview: Bool

    public init(linuxUnitTests: Bool = false, macOSArm64BuildTests: Bool = false,
                macOSIntelBuildTests: Bool = false, pairedPhysicalMacHandoff: Bool = false,
                disconnectFailsOpen: Bool = false, permissionRevocationFailsOpen: Bool = false,
                authenticatedEncryptedTransport: Bool = false, signedAndNotarized: Bool = false,
                uiAccessibilityReview: Bool = false) {
        self.linuxUnitTests = linuxUnitTests
        self.macOSArm64BuildTests = macOSArm64BuildTests
        self.macOSIntelBuildTests = macOSIntelBuildTests
        self.pairedPhysicalMacHandoff = pairedPhysicalMacHandoff
        self.disconnectFailsOpen = disconnectFailsOpen
        self.permissionRevocationFailsOpen = permissionRevocationFailsOpen
        self.authenticatedEncryptedTransport = authenticatedEncryptedTransport
        self.signedAndNotarized = signedAndNotarized
        self.uiAccessibilityReview = uiAccessibilityReview
    }

    public var stableEligible: Bool {
        linuxUnitTests && macOSArm64BuildTests && macOSIntelBuildTests &&
        pairedPhysicalMacHandoff && disconnectFailsOpen &&
        permissionRevocationFailsOpen && authenticatedEncryptedTransport &&
        signedAndNotarized && uiAccessibilityReview
    }

    public var outstanding: [String] {
        var missing = [String]()
        if !linuxUnitTests { missing.append("Linux unit tests") }
        if !macOSArm64BuildTests { missing.append("Apple Silicon build/tests") }
        if !macOSIntelBuildTests { missing.append("Intel build/tests") }
        if !pairedPhysicalMacHandoff { missing.append("Two-Mac physical handoff") }
        if !disconnectFailsOpen { missing.append("Disconnect fail-open on hardware") }
        if !permissionRevocationFailsOpen { missing.append("Permission revoke fail-open") }
        if !authenticatedEncryptedTransport { missing.append("Authenticated encryption") }
        if !signedAndNotarized { missing.append("Developer ID signing and notarization") }
        if !uiAccessibilityReview { missing.append("macOS accessibility review") }
        return missing
    }
}
