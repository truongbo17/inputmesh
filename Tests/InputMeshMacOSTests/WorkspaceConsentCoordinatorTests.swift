#if os(macOS)
import Foundation
import XCTest
import InputMeshWorkspace
@testable import InputMeshMacOS

private final class ConsentTestPersistence: WorkspacePeerTrustPersistence {
    var keys: [Data] = []
    func load() throws -> [Data] { keys }
    func save(_ value: [Data]) throws { keys = value }
}

final class WorkspaceConsentCoordinatorTests: XCTestCase {
    private let sha = String(repeating: "a", count: 40)

    private func manifest() throws -> WorkspaceManifest {
        try WorkspaceManifest(sourceDeviceName: "Mac A",
            repository: RepositorySnapshot(origin: "https://github.com/example/project.git",
                branch: "main", headSHA: sha, hasUncommittedChanges: false, hasUntrackedFiles: false))
    }

    private struct Peers {
        let a: WorkspaceConsentCoordinator
        let b: WorkspaceConsentCoordinator
        let storeA: WorkspacePeerTrustStore
        let storeB: WorkspacePeerTrustStore
        let keyA: Data
        let keyB: Data
        let code: String
    }

    private func pairedBeforeApproval() throws -> Peers {
        let identityA = MacDeviceIdentity()
        let identityB = MacDeviceIdentity()
        let storeA = WorkspacePeerTrustStore(persistence: ConsentTestPersistence())
        let storeB = WorkspacePeerTrustStore(persistence: ConsentTestPersistence())
        let a = try WorkspaceConsentCoordinator(identity: identityA, role: .initiator, trustStore: storeA)
        let b = try WorkspaceConsentCoordinator(identity: identityB, role: .responder, trustStore: storeB)
        let helloA = try a.begin()
        let helloB = try b.begin()
        let proofA = try a.receive(helloB).outgoing[0]
        let proofB = try b.receive(helloA).outgoing[0]
        let resultA = try a.receive(proofB)
        let resultB = try b.receive(proofA)
        guard case let .pairingCode(codeA)? = resultA.event,
              case let .pairingCode(codeB)? = resultB.event else {
            XCTFail("Both sides must display pairing code")
            throw WorkspaceConsentError.invalidState
        }
        XCTAssertEqual(codeA, codeB)
        XCTAssertFalse(try storeA.isTrusted(identityB.publicKey))
        XCTAssertFalse(try storeB.isTrusted(identityA.publicKey))
        return Peers(a: a, b: b, storeA: storeA, storeB: storeB,
                     keyA: identityA.publicKey, keyB: identityB.publicKey, code: codeA)
    }

    private func approved() throws -> Peers {
        let p = try pairedBeforeApproval()
        let ackA = try p.a.confirmPairing(code: p.code).outgoing[0]
        XCTAssertFalse(p.a.isReady)
        // Out-of-order human confirmations must be supported: B sees A's
        // encrypted acceptance before B's own approval, and buffers it.
        XCTAssertNil(try p.b.receive(ackA).event)
        XCTAssertFalse(try p.storeB.isTrusted(p.keyA))
        let resultB = try p.b.confirmPairing(code: p.code)
        XCTAssertEqual(resultB.event, .ready)
        XCTAssertTrue(p.b.isReady)
        XCTAssertEqual(try p.a.receive(resultB.outgoing[0]).event, .ready)
        XCTAssertTrue(try p.storeA.isTrusted(p.keyB))
        XCTAssertTrue(try p.storeB.isTrusted(p.keyA))
        return p
    }

    func testMutualApprovalRequiredBeforeAnyManifestAndNoPrematureTrust() throws {
        let p = try pairedBeforeApproval()
        XCTAssertThrowsError(try p.a.sendManifest(manifest()))
        let ackA = try p.a.confirmPairing(code: p.code).outgoing[0]
        XCTAssertFalse(try p.storeA.isTrusted(p.keyB))
        XCTAssertFalse(p.a.isReady)
        XCTAssertThrowsError(try p.a.sendManifest(manifest()))
        XCTAssertNil(try p.b.receive(ackA).event)
        XCTAssertFalse(try p.storeB.isTrusted(p.keyA))
        let ackB = try p.b.confirmPairing(code: p.code).outgoing[0]
        XCTAssertEqual(try p.a.receive(ackB).event, .ready)
        XCTAssertTrue(try p.storeA.isTrusted(p.keyB))
    }

    func testManifestTimestampRoundTripIsCanonical() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000.789)
        let snapshot = try WorkspaceManifest(createdAt: timestamp, sourceDeviceName: "Mac A",
            repository: RepositorySnapshot(origin: "https://github.com/example/project.git",
                branch: "main", headSHA: sha, hasUncommittedChanges: false, hasUntrackedFiles: false))
        XCTAssertEqual(snapshot.createdAt.timeIntervalSince1970, 1_700_000_000)
        XCTAssertEqual(try WorkspaceManifest.decode(snapshot.encodedData()), snapshot)
    }

    func testCompleteManifestHandoffIsInertAndBoundToSession() throws {
        let p = try approved()
        let m = try manifest()
        let encrypted = try p.a.sendManifest(m)
        XCTAssertEqual(try p.b.receive(encrypted).event, .manifest(m))
        XCTAssertThrowsError(try p.b.receive(encrypted)) // replay closes peer
        XCTAssertEqual(p.b.phase, .closed)
    }

    func testBadCodeCannotAuthorizeOrTrust() throws {
        let p = try pairedBeforeApproval()
        XCTAssertThrowsError(try p.a.confirmPairing(code: "00000-00000"))
        XCTAssertFalse(try p.storeA.isTrusted(p.keyB))
        XCTAssertFalse(p.a.isReady)
        XCTAssertNoThrow(try p.a.confirmPairing(code: p.code))
    }

    func testForgedProofOrEarlyEncryptedPayloadClosesSession() throws {
        let a = try WorkspaceConsentCoordinator(identity: MacDeviceIdentity(),
                                                 role: .initiator,
                                                 trustStore: WorkspacePeerTrustStore(persistence: ConsentTestPersistence()))
        let b = try WorkspaceConsentCoordinator(identity: MacDeviceIdentity(),
                                                 role: .responder,
                                                 trustStore: WorkspacePeerTrustStore(persistence: ConsentTestPersistence()))
        let ha = try a.begin()
        let hb = try b.begin()
        _ = try a.receive(hb)
        _ = try b.receive(ha)
        let forged = try WorkspaceWireEnvelope(kind: .proof, payload: Data(repeating: 9, count: 64))
        XCTAssertThrowsError(try a.receive(forged))
        XCTAssertEqual(a.phase, .closed)

        let c = try WorkspaceConsentCoordinator(identity: MacDeviceIdentity(), role: .initiator)
        _ = try c.begin()
        let early = try WorkspaceWireEnvelope(kind: .sealed, payload: Data(repeating: 1, count: 36))
        XCTAssertThrowsError(try c.receive(early))
        XCTAssertEqual(c.phase, .closed)
    }

    func testTamperAndRevocationFailClosed() throws {
        let p = try approved()
        var data = try p.a.sendManifest(manifest()).payload
        data[data.count - 1] ^= 1
        let tampered = try WorkspaceWireEnvelope(kind: .sealed, payload: data)
        XCTAssertThrowsError(try p.b.receive(tampered))
        XCTAssertEqual(p.b.phase, .closed)

        try p.storeA.revoke(p.keyB)
        XCTAssertThrowsError(try p.a.sendManifest(manifest()))
        XCTAssertEqual(p.a.phase, .closed)
    }

    func testGoodbyeDisablesFurtherMessages() throws {
        let p = try approved()
        let bye = try WorkspaceWireEnvelope(kind: .goodbye, payload: Data())
        XCTAssertEqual(try p.a.receive(bye).event, .closed)
        XCTAssertThrowsError(try p.a.sendManifest(manifest()))
    }
}
#endif
