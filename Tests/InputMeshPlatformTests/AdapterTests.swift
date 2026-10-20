import XCTest
import InputMeshCore
@testable import InputMeshPlatform

private enum MockError: Error { case failed }

private final class RecordingInjector: InputInjecting {
    var events: [InputPayload] = []
    var failNext = false

    func inject(_ payload: InputPayload) throws {
        if failNext { failNext = false; throw MockError.failed }
        events.append(payload)
    }
}

final class AdapterTests: XCTestCase {
    func testAuthorizedDeliveryAndIdempotentRevoke() throws {
        let id = UUID()
        let lease = RemoteLease(deviceID: "target", displayID: "screen", sessionID: id, epoch: 1)
        var gate = AuthorizedInputGate()
        let injector = RecordingInjector()
        gate.activate(lease: lease, authenticatedSourceDeviceID: "source")
        let key = InputEnvelope(sessionID: id, epoch: 1, sequence: 1,
                                payload: .key(code: 59, down: true, modifiers: 0))
        XCTAssertFalse(try gate.deliver(key, authenticatedDeviceID: "untrusted", through: injector))
        XCTAssertTrue(injector.events.isEmpty)
        XCTAssertTrue(try gate.deliver(key, authenticatedDeviceID: "source", through: injector))
        XCTAssertFalse(try gate.deliver(key, authenticatedDeviceID: "source", through: injector))
        XCTAssertEqual(gate.revoke(through: injector), 0)
        XCTAssertEqual(injector.events, [.key(code: 59, down: true, modifiers: 0),
                                         .key(code: 59, down: false, modifiers: 0)])
        XCTAssertFalse(try gate.deliver(InputEnvelope(sessionID: id, epoch: 1, sequence: 2,
                            payload: .move(dx: 1, dy: 1)), authenticatedDeviceID: "source", through: injector))
        XCTAssertEqual(gate.revoke(through: injector), 0)
        XCTAssertEqual(injector.events.count, 2)
    }

    func testFailedInjectionRevokesLeaseAndReleasesPreviouslyHeldKeys() throws {
        let id = UUID()
        let lease = RemoteLease(deviceID: "target", displayID: "screen", sessionID: id, epoch: 4)
        var gate = AuthorizedInputGate()
        let injector = RecordingInjector()
        gate.activate(lease: lease, authenticatedSourceDeviceID: "source")
        XCTAssertTrue(try gate.deliver(InputEnvelope(sessionID: id, epoch: 4, sequence: 1,
                            payload: .button(button: .left, down: true)),
                            authenticatedDeviceID: "source", through: injector))
        injector.failNext = true
        XCTAssertThrowsError(try gate.deliver(InputEnvelope(sessionID: id, epoch: 4, sequence: 2,
                            payload: .move(dx: 5, dy: 0)), authenticatedDeviceID: "source", through: injector))
        XCTAssertFalse(try gate.deliver(InputEnvelope(sessionID: id, epoch: 4, sequence: 3,
                            payload: .move(dx: 5, dy: 0)), authenticatedDeviceID: "source", through: injector))
        XCTAssertFalse(gate.activate(lease: RemoteLease(deviceID: "target", displayID: "screen",
                                                       sessionID: UUID(), epoch: 5),
                                     authenticatedSourceDeviceID: "source"))
        XCTAssertEqual(gate.revoke(through: injector), 0)
        XCTAssertTrue(gate.activate(lease: RemoteLease(deviceID: "target", displayID: "screen",
                                                      sessionID: UUID(), epoch: 6),
                                    authenticatedSourceDeviceID: "source"))
        XCTAssertEqual(injector.events, [.button(button: .left, down: true),
                                         .button(button: .left, down: false)])
    }

    func testRejectUnboundedMotion() throws {
        let id = UUID()
        var gate = AuthorizedInputGate()
        let injector = RecordingInjector()
        gate.activate(lease: RemoteLease(deviceID: "target", displayID: "screen", sessionID: id, epoch: 1),
                      authenticatedSourceDeviceID: "source")
        XCTAssertFalse(try gate.deliver(InputEnvelope(sessionID: id, epoch: 1, sequence: 1,
                          payload: .move(dx: .infinity, dy: 0)), authenticatedDeviceID: "source",
                          through: injector))
        XCTAssertFalse(try gate.deliver(InputEnvelope(sessionID: id, epoch: 1, sequence: 2,
                          payload: .scroll(dx: 0, dy: 50_000)), authenticatedDeviceID: "source",
                          through: injector))
        XCTAssertTrue(try gate.deliver(InputEnvelope(sessionID: id, epoch: 1, sequence: 1,
                          payload: .move(dx: 2, dy: -4)), authenticatedDeviceID: "source",
                          through: injector))
        XCTAssertEqual(injector.events, [.move(dx: 2, dy: -4)])
    }

    func testFailedReleaseMustBeRetriedBeforeNewLease() throws {
        let id = UUID()
        var gate = AuthorizedInputGate()
        let injector = RecordingInjector()
        gate.activate(lease: RemoteLease(deviceID: "target", displayID: "screen", sessionID: id, epoch: 1),
                      authenticatedSourceDeviceID: "source")
        try gate.deliver(InputEnvelope(sessionID: id, epoch: 1, sequence: 1,
                        payload: .key(code: 10, down: true, modifiers: 0)),
                        authenticatedDeviceID: "source", through: injector)
        injector.failNext = true
        XCTAssertEqual(gate.revoke(through: injector), 1)
        XCTAssertFalse(gate.activate(lease: RemoteLease(deviceID: "target", displayID: "screen",
                                                       sessionID: UUID(), epoch: 2),
                                     authenticatedSourceDeviceID: "source"))
        XCTAssertEqual(gate.revoke(through: injector), 0)
        XCTAssertEqual(injector.events.last, .key(code: 10, down: false, modifiers: 0))
    }
}
