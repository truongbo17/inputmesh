import XCTest
@testable import InputMeshCore

final class ReplayTests: XCTestCase {
    func testReplayAndCrossSessionRejected() {
        let session = UUID()
        let lease = RemoteLease(deviceID: "mac-target", displayID: "display-remote", sessionID: session, epoch: 7)
        var guarder = ReplayGuard()
        guarder.activate(lease, permittedSourceDeviceID: "mac-source")
        let packet1 = InputEnvelope(sessionID: session, epoch: 7, sequence: 1, payload: .move(dx: 1, dy: 2))
        XCTAssertTrue(guarder.accept(packet1, authenticatedDeviceID: "mac-source"))
        XCTAssertFalse(guarder.accept(packet1, authenticatedDeviceID: "mac-source"))
        XCTAssertFalse(guarder.accept(InputEnvelope(sessionID: session, epoch: 6, sequence: 2,
                                                  payload: .move(dx: 1, dy: 2)), authenticatedDeviceID: "mac-source"))
        XCTAssertFalse(guarder.accept(InputEnvelope(sessionID: session, epoch: 7, sequence: 3,
                                                  payload: .move(dx: 1, dy: 2)), authenticatedDeviceID: "attacker"))
        XCTAssertTrue(guarder.accept(InputEnvelope(sessionID: session, epoch: 7, sequence: 2,
                                                 payload: .move(dx: 1, dy: 2)), authenticatedDeviceID: "mac-source"))
        guarder.invalidate()
        XCTAssertFalse(guarder.accept(packet1, authenticatedDeviceID: "mac-source"))
    }
}
