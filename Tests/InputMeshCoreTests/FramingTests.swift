import XCTest
@testable import InputMeshCore

final class FramingTests: XCTestCase {
    private func sample(_ sequence: UInt64 = 1) -> InputEnvelope {
        InputEnvelope(sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                      epoch: 1, sequence: sequence,
                      payload: .key(code: 5, down: true, modifiers: 0))
    }

    func testRoundTripAndFragmentation() throws {
        let frame = try FrameCodec.encode(sample())
        var decoder = FrameDecoder()
        XCTAssertEqual(try decoder.append(frame.prefix(2)), [])
        XCTAssertEqual(try decoder.append(frame.dropFirst(2).prefix(5)), [])
        let decoded = try decoder.append(frame.dropFirst(7))
        XCTAssertEqual(decoded, [sample()])
    }

    func testMultipleFramesOneChunk() throws {
        var frame = try FrameCodec.encode(sample(1))
        frame.append(try FrameCodec.encode(sample(2)))
        var decoder = FrameDecoder()
        XCTAssertEqual(try decoder.append(frame), [sample(1), sample(2)])
    }

    func testOversizedAndZeroFramesRejected() throws {
        var decoder = FrameDecoder()
        XCTAssertThrowsError(try decoder.append(Data([0, 1, 0, 1]))) { error in
            XCTAssertEqual(error as? FrameError, .frameTooLarge)
        }
        XCTAssertThrowsError(try decoder.append(Data([0, 0, 0, 0]))) { error in
            XCTAssertEqual(error as? FrameError, .emptyPayload)
        }
    }

    func testMalformedPayloadRejectedAndCleared() throws {
        var decoder = FrameDecoder()
        XCTAssertThrowsError(try decoder.append(Data([0, 0, 0, 2, 123, 125])))
        XCTAssertEqual(try decoder.append(FrameCodec.encode(sample())), [sample()])
    }

    func testHugeChunkRejected() {
        var decoder = FrameDecoder()
        XCTAssertThrowsError(try decoder.append(Data(repeating: 0, count: FrameCodec.maxChunk + 1)))
    }
}
