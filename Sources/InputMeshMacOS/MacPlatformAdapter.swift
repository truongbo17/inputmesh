#if os(macOS)
import AppKit
import ApplicationServices
import InputMeshCore
import InputMeshPlatform

/// Screen frames originate in AppKit points (bottom-left origin), then map to
/// the common virtual top-left origin used by portable topology algorithms.
/// The device ID is assigned by the caller; it is not an authentication identity.
public struct MacDisplayEnumerator: DisplayEnumerating {
    public init() {}

    public func activeDisplays(deviceID: String) throws -> [VirtualDisplay] {
        let screens = NSScreen.screens
        let top = screens.map { $0.frame.maxY }.max() ?? 0
        return try screens.compactMap { screen -> VirtualDisplay? in
            guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let r = screen.frame
            return VirtualDisplay(
                id: "mac-display-\(n.uint32Value)", deviceID: deviceID,
                frame: try VirtualRect(x: r.minX, y: top - r.maxY,
                                       width: r.width, height: r.height))
        }
    }
}

public struct MacInputPermissions: InputPermissionChecking {
    public init() {}

    public func capturePermission() -> InputAccess {
        // Input Monitoring and Accessibility are separate macOS permissions;
        // the former is intentionally not inferred from AXIsProcessTrusted.
        return .notDetermined
    }

    public func injectionPermission() -> InputAccess {
        AXIsProcessTrusted() ? .authorized : .denied
    }
}
#endif
