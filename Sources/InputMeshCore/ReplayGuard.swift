import Foundation

/// Ensures a receiver only accepts packets belonging to its active lease and with a
/// strictly increasing sequence number. Must be applied after peer authentication.
public struct ReplayGuard: Sendable {
    private var lease: RemoteLease?
    private var permittedSourceDeviceID: String?
    private var lastSequence: UInt64?

    public init() {}

    public mutating func activate(_ lease: RemoteLease, permittedSourceDeviceID: String) {
        self.lease = lease
        self.permittedSourceDeviceID = permittedSourceDeviceID
        lastSequence = nil
    }

    public mutating func invalidate() {
        lease = nil
        permittedSourceDeviceID = nil
        lastSequence = nil
    }

    @discardableResult
    public mutating func accept(_ input: InputEnvelope, authenticatedDeviceID: String) -> Bool {
        guard let lease,
              permittedSourceDeviceID == authenticatedDeviceID,
              input.sessionID == lease.sessionID,
              input.epoch == lease.epoch,
              input.version == InputEnvelope.currentVersion,
              input.sequence > 0 else { return false }
        if let lastSequence, input.sequence <= lastSequence { return false }
        lastSequence = input.sequence
        return true
    }
}
