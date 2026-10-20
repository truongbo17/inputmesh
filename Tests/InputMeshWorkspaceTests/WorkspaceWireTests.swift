import Foundation
import XCTest
@testable import InputMeshWorkspace

final class WorkspaceWireTests: XCTestCase {
    private func hello() throws -> WorkspaceWireEnvelope {
        try WorkspaceWireEnvelope(kind: .hello, payload: Data("hello".utf8))
    }

    func testOneByteFragmentsAndConcatenatedFrames() throws {
        let h = try hello()
        let p = try WorkspaceWireEnvelope(kind: .proof, payload: Data(repeating: 7, count: 64))
        let frames = try WorkspaceWireCodec.encode(h) + WorkspaceWireCodec.encode(p)
        var decoder = WorkspaceWireDecoder()
        var result: [WorkspaceWireEnvelope] = []
        for value in frames { result += try decoder.append(Data([value])) }
        XCTAssertEqual(result, [h, p])
        var together = WorkspaceWireDecoder()
        XCTAssertEqual(try together.append(frames), [h, p])
    }

    func testRejectHugeLengthAndHugeChunk() throws {
        var decoder = WorkspaceWireDecoder()
        XCTAssertThrowsError(try decoder.append(Data([255,255,255,255])))
        XCTAssertThrowsError(try decoder.append(Data(repeating: 9, count: 256*1024+1)))
    }

    func testRejectInvalidMessagesAndUnknownVersion() throws {
        XCTAssertThrowsError(try WorkspaceWireEnvelope(kind: .hello, payload: Data()))
        XCTAssertThrowsError(try WorkspaceWireEnvelope(kind: .proof, payload: Data(count: 513)))
        XCTAssertThrowsError(try WorkspaceWireEnvelope(kind: .sealed, payload: Data(count: 5)))
        XCTAssertThrowsError(try WorkspaceWireEnvelope(kind: .goodbye, payload: Data([1])))
        let valid = try WorkspaceWireCodec.encode(hello())
        var text = String(data: valid.dropFirst(4), encoding: .utf8)!
        text = text.replacingOccurrences(of: "\"version\":1", with: "\"version\":99")
        let payload = Data(text.utf8)
        var n = UInt32(payload.count).bigEndian
        let frame = withUnsafeBytes(of: &n) { Data($0) } + payload
        var decoder = WorkspaceWireDecoder()
        XCTAssertThrowsError(try decoder.append(frame))
    }

    func testPolicyBlocksEarlySealedManifestAndUnverifiedConsent() throws {
        var policy = WorkspaceWirePolicy()
        XCTAssertFalse(policy.maySendWorkspace)
        XCTAssertThrowsError(try policy.receive(.sealed))
        try policy.receive(.hello)
        XCTAssertThrowsError(try policy.receive(.sealed))
        try policy.receive(.proof)
        XCTAssertThrowsError(try policy.markLocalUserApproved())
        try policy.markPeerProofVerified()
        XCTAssertThrowsError(try policy.receive(.sealed))
        try policy.markLocalUserApproved()
        try policy.receive(.sealed) // still only an opaque encrypted ACK candidate
        XCTAssertFalse(policy.maySendWorkspace)
        try policy.markEncryptedPeerConsentVerified()
        XCTAssertTrue(policy.maySendWorkspace)
        try policy.receive(.sealed)
        policy.close()
        XCTAssertFalse(policy.maySendWorkspace)
        XCTAssertThrowsError(try policy.receive(.sealed))
    }

    func testDuplicateHelloAndPhaseBypassDenied() throws {
        var policy = WorkspaceWirePolicy()
        try policy.receive(.hello)
        XCTAssertThrowsError(try policy.receive(.hello))
        XCTAssertThrowsError(try policy.markPeerProofVerified())
        XCTAssertThrowsError(try policy.markEncryptedPeerConsentVerified())
        try policy.receive(.goodbye)
        XCTAssertFalse(policy.maySendWorkspace)
    }
}
