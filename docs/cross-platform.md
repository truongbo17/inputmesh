# Cross-platform extension contract (design, not support claim)

## Core principle

A device is identified by a cryptographic peer identity and advertises **capabilities** independently of the operating system. The caller must never infer trust, privileges, or feature availability solely from a platform string. The platform-neutral `HostPlatform` enum is currently macOS, Windows and Linux; extending to other device types requires an explicit versioned protocol revision.

## Native adapter obligations

| Contract | macOS (initial) | Windows (future) | Linux (future) |
|---|---|---|---|
| Pointer/keyboard capture | Quartz event tap | Raw Input + low-level hooks / supported desktop APIs | X11 or compositor-authorized Wayland interfaces |
| Event injection | Quartz events | SendInput with integrity-level restrictions | XTest/uinput where permitted; Wayland compositor-specific |
| Displays | CoreGraphics displays | Windows display enumeration | XRandR/Wayland output APIs |
| Permissions | Accessibility / Input Monitoring as required | Session rights and integrity levels | Compositor, seat and portal/device access policies |
| Safety | Source fail-back, receiver release, secure-input limitations | UAC secure desktop is out of scope | Some Wayland environments may prohibit global input capture |

Adapters expose only OS-neutral `InputPayload`, `VirtualDisplay` and capability/permission contracts. Not every desktop can support every feature; unavailable capabilities must be reported, not silently bypassed via elevation or unsafe OS configuration.

## Key event semantics

`key(code:down:modifiers:)` currently models **macOS-style virtual keycodes** during Sprint 0. **This is not yet a cross-platform wire contract.** Interop needs a language-neutral physical key representation (e.g. USB HID usage page+usage) and platform translation tables. Text/IME composition must remain target-native and requires specific keyboard-layout regression cases.

## Transport contract to formalize in a future sprint

Use a single shared IDL (Protobuf proposed), with explicit network protocol version, session/epoch/sequence, device/display IDs, logical cursor transition and bounded payload sizes. Identity must be verified by mTLS and a persisted pairing decision before granting a lease. A raw JSON frame is *development-only* and must not be accepted by a network listener as proof of authentication.

## Definition of readiness for a new platform

1. Local capture and injection validated in a disposable user session with standard user privileges.
2. Permissions and denial paths are explainable and reversible; no root/SIP/policy bypass requirements.
3. Supported/unsupported capability matrix is published.
4. Security, sequence, malformed-frame, cross-layout and fail-back tests pass.
5. Real two-platform pointer/keyboard handoff is documented and benchmarked.
