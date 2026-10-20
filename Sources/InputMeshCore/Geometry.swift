import Foundation

/// Virtual display coordinates are expressed in points, top-left origin, with +Y downward.
/// They do not represent CoreGraphics global-display pixel coordinates.
public struct VirtualPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct VirtualRect: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) throws {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              (x + width).isFinite, (y + height).isFinite,
              width > 0, height > 0 else { throw GeometryError.invalidRect }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }

    public func contains(_ p: VirtualPoint) -> Bool {
        p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY
    }
}

public enum GeometryError: Error, Equatable {
    case invalidRect
    case duplicateDisplayID
    case missingDisplay
    case invalidGap
}

public enum ScreenEdge: String, Codable, Sendable {
    case left, right, top, bottom
}

public struct VirtualDisplay: Codable, Hashable, Sendable {
    public let id: String
    public let deviceID: String
    public let frame: VirtualRect

    public init(id: String, deviceID: String, frame: VirtualRect) {
        self.id = id
        self.deviceID = deviceID
        self.frame = frame
    }
}

public struct BoundaryCrossing: Equatable, Sendable {
    public let source: VirtualDisplay
    public let target: VirtualDisplay
    public let targetPoint: VirtualPoint
    public let edge: ScreenEdge
}

/// Stateless topology lookup. Display mapping is explicit and independent of screen order.
public struct ScreenTopology: Sendable {
    public let displays: [VirtualDisplay]
    public let maxGap: Double
    private let displayByID: [String: VirtualDisplay]

    public init(displays: [VirtualDisplay], maxGap: Double = 24) throws {
        guard maxGap.isFinite, maxGap >= 0 else { throw GeometryError.invalidGap }
        let dict = Dictionary(displays.map { ($0.id, $0) }, uniquingKeysWith: { lhs, _ in lhs })
        guard dict.count == displays.count else { throw GeometryError.duplicateDisplayID }
        self.displays = displays
        self.maxGap = maxGap
        self.displayByID = dict
    }

    public func display(id: String) -> VirtualDisplay? { displayByID[id] }

    /// Maps a cursor coordinate that has crossed a boundary to the closest adjacent display.
    /// Overshoot in the movement axis is preserved, but is clamped inside the target display.
    public func cross(from displayID: String, at cursor: VirtualPoint, edge: ScreenEdge) -> BoundaryCrossing? {
        guard let source = displayByID[displayID], cursor.x.isFinite, cursor.y.isFinite else { return nil }
        let src = source.frame
        let outside: Bool
        switch edge {
        case .left: outside = cursor.x < src.minX && cursor.y >= src.minY && cursor.y < src.maxY
        case .right: outside = cursor.x >= src.maxX && cursor.y >= src.minY && cursor.y < src.maxY
        case .top: outside = cursor.y < src.minY && cursor.x >= src.minX && cursor.x < src.maxX
        case .bottom: outside = cursor.y >= src.maxY && cursor.x >= src.minX && cursor.x < src.maxX
        }
        guard outside else { return nil }

        let eligible = displays.compactMap { candidate -> (VirtualDisplay, Double, Double)? in
            guard candidate.id != source.id else { return nil }
            let r = candidate.frame
            let gap: Double
            let overlap: Double
            switch edge {
            case .right:
                gap = r.minX - src.maxX
                overlap = min(src.maxY, r.maxY) - max(src.minY, r.minY)
            case .left:
                gap = src.minX - r.maxX
                overlap = min(src.maxY, r.maxY) - max(src.minY, r.minY)
            case .bottom:
                gap = r.minY - src.maxY
                overlap = min(src.maxX, r.maxX) - max(src.minX, r.minX)
            case .top:
                gap = src.minY - r.maxY
                overlap = min(src.maxX, r.maxX) - max(src.minX, r.minX)
            }
            // Only transfer along an *actual shared edge segment*. Selecting a
            // neighboring display by overlap size alone can route the cursor to
            // a screen that isn't beside the pointer (e.g. vertically stacked peers).
            // Keep global tangential positions stable instead of rescaling the
            // full source height and producing a visible jump.
            let tangentialInOverlap: Bool
            switch edge {
            case .right, .left:
                tangentialInOverlap = cursor.y >= max(src.minY, r.minY) &&
                                      cursor.y < min(src.maxY, r.maxY)
            case .bottom, .top:
                tangentialInOverlap = cursor.x >= max(src.minX, r.minX) &&
                                      cursor.x < min(src.maxX, r.maxX)
            }
            // Overlapping virtual displays are not edge neighbors.
            guard gap >= -0.001, gap <= maxGap, overlap > 0, tangentialInOverlap else { return nil }
            return (candidate, max(0, gap), overlap)
        }
        guard let target = eligible.sorted(by: { a, b in
            if abs(a.1 - b.1) > 0.001 { return a.1 < b.1 }
            if abs(a.2 - b.2) > 0.001 { return a.2 > b.2 }
            return a.0.id < b.0.id
        }).first?.0 else { return nil }

        let dst = target.frame
        let epsilon = 0.001
        let p: VirtualPoint
        switch edge {
        case .right, .left:
            let y = min(dst.maxY - epsilon, max(dst.minY, cursor.y))
            let overflow = edge == .right ? cursor.x - src.maxX : src.minX - cursor.x
            let x = edge == .right
                ? min(dst.maxX - epsilon, dst.minX + max(0, overflow))
                : max(dst.minX, dst.maxX - epsilon - max(0, overflow))
            p = VirtualPoint(x: x, y: y)
        case .bottom, .top:
            let x = min(dst.maxX - epsilon, max(dst.minX, cursor.x))
            let overflow = edge == .bottom ? cursor.y - src.maxY : src.minY - cursor.y
            let y = edge == .bottom
                ? min(dst.maxY - epsilon, dst.minY + max(0, overflow))
                : max(dst.minY, dst.maxY - epsilon - max(0, overflow))
            p = VirtualPoint(x: x, y: y)
        }
        return BoundaryCrossing(source: source, target: target, targetPoint: p, edge: edge)
    }
}
