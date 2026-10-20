import Foundation

public struct RemoteLease: Equatable, Sendable {
    public let deviceID: String
    public let displayID: String
    public let sessionID: UUID
    public let epoch: UInt64

    public init(deviceID: String, displayID: String, sessionID: UUID, epoch: UInt64) {
        self.deviceID = deviceID
        self.displayID = displayID
        self.sessionID = sessionID
        self.epoch = epoch
    }
}

public enum SessionState: Equatable, Sendable {
    case local
    case switching(RemoteLease)
    case remote(RemoteLease)
    case recovering
}

public enum SessionError: Error, Equatable {
    case invalidTransition
    case staleAcknowledgement
    case epochOverflow
}

/// Deterministic, transport-agnostic state machine. A switch must be acknowledged before
/// the source can suppress local input. On failures, recover local ownership immediately.
public struct InputSession: Sendable {
    private(set) public var state: SessionState = .local
    private(set) public var epoch: UInt64 = 0

    public init() {}

    @discardableResult
    public mutating func requestSwitch(deviceID: String, displayID: String, sessionID: UUID = UUID()) throws -> RemoteLease {
        guard state == .local else { throw SessionError.invalidTransition }
        guard epoch < UInt64.max else { throw SessionError.epochOverflow }
        epoch += 1
        let lease = RemoteLease(deviceID: deviceID, displayID: displayID, sessionID: sessionID, epoch: epoch)
        state = .switching(lease)
        return lease
    }

    public mutating func acknowledge(_ lease: RemoteLease) throws {
        guard case let .switching(expected) = state else { throw SessionError.invalidTransition }
        guard lease == expected else { throw SessionError.staleAcknowledgement }
        state = .remote(expected)
    }

    /// Safe fallback. This method is intentionally idempotent and never waits for a network call.
    public mutating func recover() { state = .recovering }
    public mutating func restoreLocal() { state = .local }

    /// Called after an authenticated remote release acknowledgement, or after fail-safe recovery.
    public mutating func endRemote() throws {
        guard case .remote = state else { throw SessionError.invalidTransition }
        state = .recovering
    }
}

public enum InputRoute: Equatable, Sendable {
    case local
    case remote(RemoteLease)
}

public enum InputRouter {
    /// In switching and recovery, input stays on the physical owner (never silently disappears).
    public static func route(for state: SessionState) -> InputRoute {
        guard case let .remote(lease) = state else { return .local }
        return .remote(lease)
    }
}
