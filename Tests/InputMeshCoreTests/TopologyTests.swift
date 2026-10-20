import XCTest
@testable import InputMeshCore

final class TopologyTests: XCTestCase {
    func display(_ id: String, _ device: String, _ x: Double, _ y: Double,
                 _ w: Double = 100, _ h: Double = 100) throws -> VirtualDisplay {
        VirtualDisplay(id: id, deviceID: device,
                  frame: try VirtualRect(x: x, y: y, width: w, height: h))
    }

    func testThreeMacsChainedAndBackwards() throws {
        let topo = try ScreenTopology(displays: [
            display("A", "mac-a", 0, 0), display("B", "mac-b", 100, 0),
            display("C", "mac-c", 200, 0)])
        let ab = try XCTUnwrap(topo.cross(from: "A", at: VirtualPoint(x: 103, y: 25), edge: .right))
        XCTAssertEqual(ab.target.id, "B")
        XCTAssertEqual(ab.targetPoint.x, 103, accuracy: 0.01)
        XCTAssertEqual(ab.targetPoint.y, 25, accuracy: 0.01)
        let bc = try XCTUnwrap(topo.cross(from: "B", at: VirtualPoint(x: 202, y: 60), edge: .right))
        XCTAssertEqual(bc.target.id, "C")
        let cb = try XCTUnwrap(topo.cross(from: "C", at: VirtualPoint(x: 198, y: 60), edge: .left))
        XCTAssertEqual(cb.target.id, "B")
    }

    func testVerticalAndDifferentHeights() throws {
        let topo = try ScreenTopology(displays: [
            display("A", "a", 0, 0, 100, 200),
            display("B", "b", 100, 0, 100, 100),
            display("C", "c", 0, 200, 100, 100)])
        let aToB = try XCTUnwrap(topo.cross(from: "A", at: VirtualPoint(x: 101, y: 100), edge: .right))
        XCTAssertEqual(aToB.targetPoint.y, 50, accuracy: 0.01)
        let aToC = try XCTUnwrap(topo.cross(from: "A", at: VirtualPoint(x: 25, y: 202), edge: .bottom))
        XCTAssertEqual(aToC.target.id, "C")
    }

    func testNoNeighborAndGapLimit() throws {
        let topo = try ScreenTopology(displays: [
            display("A", "a", 0, 0), display("B", "b", 150, 0)])
        XCTAssertNil(topo.cross(from: "A", at: VirtualPoint(x: 101, y: 20), edge: .right))
        XCTAssertNil(topo.cross(from: "A", at: VirtualPoint(x: 10, y: 20), edge: .right))
    }

    func testTopBottomAndGap() throws {
        let topo = try ScreenTopology(displays: [
            display("A", "a", 0, 0), display("B", "b", 0, 110)], maxGap: 15)
        XCTAssertEqual(topo.cross(from: "A", at: VirtualPoint(x: 50, y: 101), edge: .bottom)?.target.id, "B")
        XCTAssertEqual(topo.cross(from: "B", at: VirtualPoint(x: 50, y: 109), edge: .top)?.target.id, "A")
    }

    func testBadRectAndDuplicateDisplay() throws {
        XCTAssertThrowsError(try VirtualRect(x: 0, y: 0, width: 0, height: 1))
        XCTAssertThrowsError(try VirtualRect(x: .infinity, y: 0, width: 1, height: 1))
        let a = try display("A", "a", 0, 0)
        XCTAssertThrowsError(try ScreenTopology(displays: [a, a]))
        XCTAssertThrowsError(try ScreenTopology(displays: [a], maxGap: -.infinity))
    }

    func testSameXOverlappingIsNotNeighbor() throws {
        let topo = try ScreenTopology(displays: [display("A", "a", 0, 0), display("B", "b", 90, 0)])
        XCTAssertNil(topo.cross(from: "A", at: VirtualPoint(x: 100, y: 25), edge: .right))
    }
}

extension TopologyTests {
    func testOverflowingVirtualGeometryRejected() {
        XCTAssertThrowsError(try VirtualRect(x: Double.greatestFiniteMagnitude, y: 0,
                                            width: Double.greatestFiniteMagnitude, height: 10))
    }
}
