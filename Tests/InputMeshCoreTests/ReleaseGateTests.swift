import Foundation
import XCTest
@testable import InputMeshCore

final class ReleaseGateTests: XCTestCase {
    private func evidence() throws -> ReleaseAttestation {
        try ReleaseAttestation(evidenceURL: "https://github.com/truongbo17/inputmesh/actions",
                               verifiedBy: "test-fixture", recordedAt: Date(timeIntervalSince1970: 123))
    }

    func testDefaultFailClosedAndNoRetiredInputGates() {
        let report = ReleaseEvidence()
        XCTAssertFalse(report.stableEligible)
        XCTAssertEqual(report.outstanding.count, WorkspaceReleaseGate.allCases.count)
        XCTAssertTrue(report.outstanding.contains("Physical Mac A to Mac B workspace handoff"))
        XCTAssertFalse(report.outstanding.contains("Two-Mac physical pointer handoff"))
    }

    func testCIAloneCannotProduceStable() throws {
        var report = ReleaseEvidence()
        for gate in [WorkspaceReleaseGate.linuxCoreCI, .macOSArm64CI, .macOSIntelCI] {
            try report.record(gate, with: evidence())
        }
        XCTAssertFalse(report.stableEligible)
        XCTAssertTrue(report.outstanding.contains("Encrypted bilateral consent and session authentication"))
        XCTAssertTrue(report.outstanding.contains("Apple Developer ID signing and notarization"))
        XCTAssertTrue(report.outstanding.contains("Independent security review"))
    }

    func testEveryGateRequiresEvidenceAndSchemaVersion() throws {
        var report = ReleaseEvidence()
        for gate in WorkspaceReleaseGate.allCases { try report.record(gate, with: evidence()) }
        // This is a pure invariant test with synthetic fixture URLs, NOT QA approval.
        XCTAssertTrue(report.stableEligible)
        XCTAssertTrue(report.outstanding.isEmpty)
        let bytes = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ReleaseEvidence.self, from: bytes)
        XCTAssertEqual(report, decoded)
        XCTAssertTrue(decoded.stableEligible)
    }

    func testRejectUntrustedEvidenceURLsAndEmptyVerifier() {
        XCTAssertThrowsError(try ReleaseAttestation(evidenceURL: "file:///tmp/fake.json", verifiedBy: "Tester"))
        XCTAssertThrowsError(try ReleaseAttestation(evidenceURL: "http://example.com/qa", verifiedBy: "Tester"))
        XCTAssertThrowsError(try ReleaseAttestation(evidenceURL: "https://user:secret@host/qa", verifiedBy: "Tester"))
        XCTAssertThrowsError(try ReleaseAttestation(evidenceURL: "https://example.com/qa", verifiedBy: " "))
    }
}
