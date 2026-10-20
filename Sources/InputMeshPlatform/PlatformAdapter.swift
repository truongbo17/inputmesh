import Foundation
import InputMeshCore

/// These contracts are shared by macOS today and future Windows/Linux adapters.
/// No OS-specific types (CGEvent, HWND, X11 Display, ...) may leak into these APIs.
public protocol InputInjecting {
    func inject(_ payload: InputPayload) throws
}

public protocol DisplayEnumerating {
    func activeDisplays(deviceID: String) throws -> [VirtualDisplay]
}

public enum InputAccess: String, Sendable {
    case authorized
    case denied
    case notDetermined
    case unavailable
}

public protocol InputPermissionChecking {
    func capturePermission() -> InputAccess
    func injectionPermission() -> InputAccess
}

/// Represents only platform capabilities the adapter actually implemented.
public protocol PlatformDescribing {
    var platform: HostPlatform { get }
    var capabilities: Set<InputCapability> { get }
}

/// Security boundary: a receiver must only process events after the transport has
/// authenticated the sender and an exclusive lease has been authorized elsewhere.
/// This local gate does not perform authentication, pairing, or transport encryption.
public struct AuthorizedInputGate: Sendable {
    private var replay = ReplayGuard()
    private var pressed = PressedInputState()
    private var pendingReleases: [InputPayload] = []
    private var active = false

    public init() {}

    /// Cannot start a new lease before all previously injected down events are released.
    /// Returns false when recovery is still pending or a lease is already active.
    @discardableResult
    public mutating func activate(lease: RemoteLease, authenticatedSourceDeviceID: String) -> Bool {
        guard !active, pendingReleases.isEmpty,
              pressed.keys.isEmpty, pressed.buttons.isEmpty else { return false }
        replay.activate(lease, permittedSourceDeviceID: authenticatedSourceDeviceID)
        pressed = PressedInputState()
        active = true
        return true
    }

    /// Returns false without injecting anything for invalid identity/session/sequence.
    /// An injector error revokes the lease: callers must attempt release and recover.
    @discardableResult
    public mutating func deliver(_ packet: InputEnvelope, authenticatedDeviceID: String,
                                 through injector: any InputInjecting) throws -> Bool {
        guard active, packet.payload.isWithinSafetyLimits,
              replay.accept(packet, authenticatedDeviceID: authenticatedDeviceID) else { return false }
        do {
            try injector.inject(packet.payload)
            pressed.record(packet.payload)
            return true
        } catch {
            replay.invalidate()
            active = false
            throw error
        }
    }

    /// Release events are best effort; call on teardown while the local injector is alive.
    /// Leases become invalid before releases are posted.
    public mutating func revoke(through injector: any InputInjecting) -> Int {
        replay.invalidate()
        active = false
        pendingReleases.append(contentsOf: pressed.releaseAll())
        let outstanding = pendingReleases
        pendingReleases.removeAll()
        for payload in outstanding {
            do { try injector.inject(payload) }
            catch { pendingReleases.append(payload) }
        }
        return pendingReleases.count
    }
}
