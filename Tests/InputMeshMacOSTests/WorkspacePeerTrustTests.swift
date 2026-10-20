#if os(macOS)
import Foundation
import XCTest
@testable import InputMeshMacOS

private final class MemoryPeerPersistence: WorkspacePeerTrustPersistence {
    var keys: [Data] = []
    var failSave = false
    func load() throws -> [Data] { keys }
    func save(_ values: [Data]) throws {
        if failSave { throw WorkspaceSessionError.revoked }
        keys = values
    }
}

final class WorkspacePeerTrustTests: XCTestCase {
    private func pending() throws -> WorkspaceSessionPending {
        let a = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .initiator)
        let b = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .responder)
        return try a.verifyAndPrepare(peer: b.hello, proof: b.makeProof(for: a.hello))
    }

    func testOnlyExplicitMatchingCodeAddsTrustedPeer() throws {
        let storage = MemoryPeerPersistence()
        let store = WorkspacePeerTrustStore(persistence: storage)
        let p = try pending()
        XCTAssertFalse(try store.isTrusted(p.peerIdentity))
        XCTAssertThrowsError(try store.approve(p, enteredCode: "00000-00000"))
        XCTAssertTrue(storage.keys.isEmpty)
        _ = try store.approve(p, enteredCode: p.comparisonCode)
        XCTAssertTrue(try store.isTrusted(p.peerIdentity))
    }

    func testRevocationImmediatelyInvalidatesActiveChannel() throws {
        let store = WorkspacePeerTrustStore(persistence: MemoryPeerPersistence())
        let p = try pending()
        let channel = try store.approve(p, enteredCode: p.comparisonCode)
        _ = try channel.seal(Data("secret".utf8))
        try store.revoke(p.peerIdentity)
        XCTAssertFalse(try store.isTrusted(p.peerIdentity))
        XCTAssertThrowsError(try channel.seal(Data("after".utf8)))
        XCTAssertThrowsError(try channel.open(Data()))
    }

    func testPersistenceFailureClosesNewlyApprovedChannel() throws {
        let storage = MemoryPeerPersistence()
        storage.failSave = true
        let p = try pending()
        XCTAssertThrowsError(try WorkspacePeerTrustStore(persistence: storage)
            .approve(p, enteredCode: p.comparisonCode))
        XCTAssertTrue(storage.keys.isEmpty)
    }

    func testRejectMalformedIdentity() throws {
        let store = WorkspacePeerTrustStore(persistence: MemoryPeerPersistence())
        XCTAssertThrowsError(try store.revoke(Data(count: 31)))
    }
}
#endif
