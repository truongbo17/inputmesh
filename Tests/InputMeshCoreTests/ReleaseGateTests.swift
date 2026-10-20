import XCTest
@testable import InputMeshCore

final class ReleaseGateTests: XCTestCase {
    func testDefaultDoesNotClaimStable() {
        let evidence = ReleaseEvidence()
        XCTAssertFalse(evidence.stableEligible)
        XCTAssertEqual(evidence.outstanding.count, 9)
    }

    func testCIAloneIsNotProductionEvidence() {
        let evidence = ReleaseEvidence(linuxUnitTests: true, macOSArm64BuildTests: true, macOSIntelBuildTests: true)
        XCTAssertFalse(evidence.stableEligible)
        XCTAssertTrue(evidence.outstanding.contains("Two-Mac physical handoff"))
        XCTAssertTrue(evidence.outstanding.contains("Developer ID signing and notarization"))
    }

    func testStableOnlyWhenEveryGateSatisfied() {
        let evidence = ReleaseEvidence(linuxUnitTests: true, macOSArm64BuildTests: true,
                                      macOSIntelBuildTests: true, pairedPhysicalMacHandoff: true,
                                      disconnectFailsOpen: true, permissionRevocationFailsOpen: true,
                                      authenticatedEncryptedTransport: true, signedAndNotarized: true,
                                      uiAccessibilityReview: true)
        XCTAssertTrue(evidence.stableEligible)
        XCTAssertTrue(evidence.outstanding.isEmpty)
    }

    func testSerializationRoundTrip() throws {
        let report = ReleaseEvidence(linuxUnitTests: true)
        XCTAssertEqual(try JSONDecoder().decode(ReleaseEvidence.self, from: JSONEncoder().encode(report)), report)
    }
}
