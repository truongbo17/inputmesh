import XCTest
@testable import InputMeshCore

final class SessionTests: XCTestCase {
    func testSuccessfulSwitchRequiresAcknowledgement() throws {
        var session = InputSession()
        XCTAssertEqual(InputRouter.route(for: session.state), .local)
        let lease = try session.requestSwitch(deviceID: "mac-b", displayID: "b")
        XCTAssertEqual(InputRouter.route(for: session.state), .local)
        try session.acknowledge(lease)
        XCTAssertEqual(InputRouter.route(for: session.state), .remote(lease))
        try session.endRemote()
        XCTAssertEqual(InputRouter.route(for: session.state), .local)
        session.restoreLocal()
        XCTAssertEqual(session.state, .local)
    }

    func testStaleAckAndDoubleSwitchRejected() throws {
        var session = InputSession()
        let lease = try session.requestSwitch(deviceID: "mac-b", displayID: "b")
        XCTAssertThrowsError(try session.requestSwitch(deviceID: "mac-c", displayID: "c"))
        let invalid = RemoteLease(deviceID: lease.deviceID, displayID: lease.displayID,
                                  sessionID: UUID(), epoch: lease.epoch)
        XCTAssertThrowsError(try session.acknowledge(invalid))
        XCTAssertEqual(InputRouter.route(for: session.state), .local)
    }

    func testRecoverIdempotentAndEpochChanges() throws {
        var session = InputSession()
        let old = try session.requestSwitch(deviceID: "b", displayID: "b")
        session.recover()
        session.recover()
        session.restoreLocal()
        let current = try session.requestSwitch(deviceID: "b", displayID: "b")
        XCTAssertGreaterThan(current.epoch, old.epoch)
        XCTAssertThrowsError(try session.acknowledge(old))
        XCTAssertEqual(InputRouter.route(for: session.state), .local)
    }

    func testPressedKeysAndButtonsReleaseDeterministically() {
        var keys = PressedInputState()
        keys.record(.key(code: 55, down: true, modifiers: 0))
        keys.record(.key(code: 4, down: true, modifiers: 0))
        keys.record(.button(button: .left, down: true))
        keys.record(.key(code: 4, down: false, modifiers: 0))
        let release = keys.releaseAll()
        XCTAssertEqual(release, [
            .key(code: 55, down: false, modifiers: 0), .button(button: .left, down: false)
        ])
        XCTAssertTrue(keys.releaseAll().isEmpty)
    }
}
