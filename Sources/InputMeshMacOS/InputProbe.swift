#if os(macOS)
import Foundation
import CoreGraphics
import ApplicationServices
import InputMeshCore
import InputMeshPlatform

public enum NativeInputError: Error, LocalizedError {
    case accessibilityNotGranted
    case eventTapUnavailable
    case eventSourceUnavailable

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted: return "Grant Accessibility access in System Settings > Privacy & Security."
        case .eventTapUnavailable: return "CGEventTap creation failed. Check Input Monitoring permissions and system policy."
        case .eventSourceUnavailable: return "Could not create a Quartz input event."
        }
    }
}

/// Passive local diagnostics only: NEVER records key codes, typed text, or coordinates.
/// Future event suppression must be tied to an authenticated, acknowledged remote lease.
public final class InputProbe {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var eventCount: UInt64 = 0
    private var disabledCount: UInt64 = 0
    private var timer: Timer?

    public init() {}

    public func run() throws {
        guard AXIsProcessTrusted() else { throw NativeInputError.accessibilityNotGranted }

        let kinds: [CGEventType] = [.mouseMoved, .leftMouseDown, .leftMouseUp,
                                    .rightMouseDown, .rightMouseUp, .keyDown,
                                    .keyUp, .flagsChanged, .scrollWheel]
        let mask: CGEventMask = kinds.reduce(0) { partial, event in
            partial | (CGEventMask(1) << event.rawValue)
        }
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let probe = Unmanaged<InputProbe>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                probe.disabledCount += 1
                if let tap = probe.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else {
                probe.eventCount += 1
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .listenOnly,
                                          eventsOfInterest: mask,
                                          callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw NativeInputError.eventTapUnavailable
        }
        self.tap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)!
        self.source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Passive event probe started. Counts only; no keys or coordinates logged. Ctrl+C exits.")
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            print("5s sample: captured=\(self.eventCount), tap_disabled=\(self.disabledCount)")
            self.eventCount = 0
        }
        CFRunLoopRun()
    }

    deinit {
        timer?.invalidate()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
    }
}

/// Single-host PoC injector. Callers MUST establish authenticated permissions,
/// a valid lease, and user opt-in before ever exposing this capability over a network.
public struct QuartzInputInjector: InputInjecting {
    public init() {}

    public func inject(_ payload: InputPayload) throws {
        let event: CGEvent?
        switch payload {
        case let .key(code, down, _):
            event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: down)
        case let .button(button, down):
            let position = CGEvent(source: nil)?.location ?? .zero
            let type: CGEventType
            let cgButton: CGMouseButton
            switch button {
            case .left:
                type = down ? .leftMouseDown : .leftMouseUp
                cgButton = .left
            case .right:
                type = down ? .rightMouseDown : .rightMouseUp
                cgButton = .right
            case .middle:
                type = down ? .otherMouseDown : .otherMouseUp
                cgButton = .center
            }
            event = CGEvent(mouseEventSource: nil, mouseType: type,
                            mouseCursorPosition: position, mouseButton: cgButton)
        case let .move(dx, dy):
            guard dx.isFinite, dy.isFinite else { return }
            let position = CGEvent(source: nil)?.location ?? .zero
            let destination = CGPoint(x: position.x + dx, y: position.y + dy)
            event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                            mouseCursorPosition: destination, mouseButton: .left)
        case let .scroll(dx, dy):
            guard dx.isFinite, dy.isFinite else { return }
            event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                            wheelCount: 2,
                            wheel1: Int32(max(-32768, min(32767, dy))),
                            wheel2: Int32(max(-32768, min(32767, dx))), wheel3: 0)
        }
        guard let event else { throw NativeInputError.eventSourceUnavailable }
        event.post(tap: .cghidEventTap)
    }
}
#endif
