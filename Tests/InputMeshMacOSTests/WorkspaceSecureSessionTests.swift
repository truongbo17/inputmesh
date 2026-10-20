#if os(macOS)
import Foundation
import XCTest
@testable import InputMeshMacOS

final class WorkspaceSecureSessionTests: XCTestCase {
    private func pair() throws -> (WorkspaceSessionPending, WorkspaceSessionPending) {
        let a = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .initiator)
        let b = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .responder)
        let sigA = try a.makeProof(for: b.hello)
        let sigB = try b.makeProof(for: a.hello)
        let pa = try a.verifyAndPrepare(peer: b.hello, proof: sigB)
        let pb = try b.verifyAndPrepare(peer: a.hello, proof: sigA)
        return (pa, pb)
    }

    func testBothPeersAgreeOnSASAndExchangeCiphertext() throws {
        let (pa, pb) = try pair()
        XCTAssertEqual(pa.comparisonCode, pb.comparisonCode)
        XCTAssertEqual(pa.comparisonCode.count, 11)
        let a = try pa.activateAfterUserConfirmation(enteredCode: pa.comparisonCode)
        let b = try pb.activateAfterUserConfirmation(enteredCode: pb.comparisonCode)
        XCTAssertEqual(try b.open(a.seal(Data("hello".utf8))), Data("hello".utf8))
        XCTAssertEqual(try a.open(b.seal(Data("reply".utf8))), Data("reply".utf8))
    }

    func testForgedProofAndRoleConfusionRejected() throws {
        let a = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .initiator)
        let b = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .responder)
        let attacker = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .responder)
        XCTAssertThrowsError(try a.verifyAndPrepare(peer: b.hello,
                                                     proof: attacker.makeProof(for: a.hello)))
        let otherA = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .initiator)
        XCTAssertThrowsError(try a.makeProof(for: otherA.hello))
        let proof = try b.makeProof(for: a.hello)
        _ = try a.verifyAndPrepare(peer: b.hello, proof: proof)
        XCTAssertThrowsError(try a.verifyAndPrepare(peer: b.hello, proof: proof))
    }

    func testCodeRequiredAndPendingCannotBeReused() throws {
        let (pa, _) = try pair()
        XCTAssertThrowsError(try pa.activateAfterUserConfirmation(enteredCode: "00000-00000"))
        _ = try pa.activateAfterUserConfirmation(enteredCode: pa.comparisonCode)
        XCTAssertThrowsError(try pa.activateAfterUserConfirmation(enteredCode: pa.comparisonCode))
    }

    func testReplayTamperAndOutOfOrderAreRejected() throws {
        let (pa, pb) = try pair()
        let a = try pa.activateAfterUserConfirmation(enteredCode: pa.comparisonCode)
        let b = try pb.activateAfterUserConfirmation(enteredCode: pb.comparisonCode)
        let one = try a.seal(Data([1]))
        let two = try a.seal(Data([2]))
        XCTAssertThrowsError(try b.open(two))
        var tampered = one
        tampered[tampered.count - 1] ^= 1
        XCTAssertThrowsError(try b.open(tampered))
        XCTAssertEqual(try b.open(one), Data([1]))
        XCTAssertThrowsError(try b.open(one))
        XCTAssertEqual(try b.open(two), Data([2]))
    }

    func testFrameBoundariesAndMalformedHello() throws {
        let (pa, pb) = try pair()
        let a = try pa.activateAfterUserConfirmation(enteredCode: pa.comparisonCode)
        let b = try pb.activateAfterUserConfirmation(enteredCode: pb.comparisonCode)
        XCTAssertThrowsError(try a.seal(Data(repeating: 1, count: 65537)))
        XCTAssertThrowsError(try b.open(Data([0])))
        let h = try WorkspaceSessionHandshake(identity: MacDeviceIdentity(), role: .initiator)
        let invalid = WorkspaceSessionHello(version: 99, role: .responder,
            identityPublicKey: Data(count: 32), ephemeralPublicKey: Data(count: 32), nonce: Data(count: 32))
        XCTAssertThrowsError(try h.makeProof(for: invalid))
    }
}
#endif
