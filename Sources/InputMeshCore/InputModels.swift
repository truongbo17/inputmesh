import Foundation

public enum MouseButton: String, Codable, CaseIterable, Hashable, Sendable {
    case left, right, middle
}

public enum InputPayload: Codable, Equatable, Sendable {
    case move(dx: Double, dy: Double)
    case button(button: MouseButton, down: Bool)
    case key(code: UInt16, down: Bool, modifiers: UInt64)
    case scroll(dx: Double, dy: Double)
}

extension InputPayload {
    /// Defense-in-depth for network-derived motion. Normal pointer deltas are far smaller.
    /// Native adapters must still validate all OS-level input parameters.
    public var isWithinSafetyLimits: Bool {
        switch self {
        case let .move(dx, dy):
            return dx.isFinite && dy.isFinite && abs(dx) <= 100_000 && abs(dy) <= 100_000
        case let .scroll(dx, dy):
            return dx.isFinite && dy.isFinite && abs(dx) <= 8_192 && abs(dy) <= 8_192
        case .key, .button:
            return true
        }
    }
}

public struct InputEnvelope: Codable, Equatable, Sendable {
    public static let currentVersion: UInt16 = 1

    public let version: UInt16
    public let sessionID: UUID
    public let epoch: UInt64
    public let sequence: UInt64
    public let payload: InputPayload

    public init(sessionID: UUID, epoch: UInt64, sequence: UInt64, payload: InputPayload) {
        version = Self.currentVersion
        self.sessionID = sessionID
        self.epoch = epoch
        self.sequence = sequence
        self.payload = payload
    }
}

/// Input stuck-state recovery. Release all remote-down state on lost lease/disconnect.
public struct PressedInputState: Sendable {
    private(set) public var keys: Set<UInt16> = []
    private(set) public var buttons: Set<MouseButton> = []

    public init() {}

    public mutating func record(_ payload: InputPayload) {
        switch payload {
        case let .key(code, down, _):
            if down { keys.insert(code) } else { keys.remove(code) }
        case let .button(button, down):
            if down { buttons.insert(button) } else { buttons.remove(button) }
        default: break
        }
    }

    @discardableResult
    public mutating func releaseAll() -> [InputPayload] {
        let releases = keys.sorted().map { InputPayload.key(code: $0, down: false, modifiers: 0) }
            + buttons.sorted(by: { $0.rawValue < $1.rawValue }).map { InputPayload.button(button: $0, down: false) }
        keys.removeAll()
        buttons.removeAll()
        return releases
    }
}
