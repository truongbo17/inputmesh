# ADR 0001 — InputMesh layered architecture

Date: 2026-10-20
State: **Accepted architecture; implementation partial**

## Objective

A local-first keyboard/pointer control mesh for independent desktops. macOS ↔ macOS is the first hardware target. The core contracts must allow future Windows and Linux adapters without importing AppKit, Win32, X11 or Wayland types into routing/session logic.

## Architecture

```text
              Mac A (physical input owner)            Mac B (target)
           ┌──────────────────────────────┐      ┌──────────────────────────────┐
           │ InputMeshMacOS adapter        │      │ InputMeshMacOS adapter        │
           │ Quartz tap, cursor, perms     │      │ Authorized native injector   │
           └──────────────┬───────────────┘      └───────────────▲──────────────┘
                          │ InputMeshPlatform interfaces          │
           ┌──────────────▼───────────────┐      ┌───────────────┴──────────────┐
           │ InputMeshCore                 │      │ InputMeshCore                 │
           │ topology, state, event model  │      │ replay, pressed state, lease  │
           └──────────────┬───────────────┘      └───────────────▲──────────────┘
                          │                                       │
                          │     FUTURE transport: Go + mTLS      │
                          └──────────(not implemented)───────────┘
```

`InputMeshCore` and `InputMeshPlatform` compile on Linux with SwiftPM. These Swift targets are currently the testable domain implementation; a Go networking core is an option for subsequent sprints. If/when Go is introduced, put wire definitions under a single, language-neutral schema with explicit protocol-version negotiation, rather than duplicating unverified business rules across languages.

## Module ownership

| Module | Responsibilities | Forbidden dependencies |
|---|---|---|
| `InputMeshCore` | Virtual topology, input payload, session transitions, replay guard, profile and capability negotiation | CoreGraphics, AppKit, Win32, X11, network sockets |
| `InputMeshPlatform` | `InputInjecting`, `DisplayEnumerating`, `InputPermissionChecking`, `PlatformDescribing`; receiving-side gate | Any concrete OS API |
| `InputMeshMacOS` | Quartz passive capture probe and local event-injector adapter | Trust policy or network authentication bypass |
| `InputMeshCLI` | Explicit local diagnostics only | Background listener without opt-in |
| Future secure transport | Peer identity, pairing, lease authorization, encrypted messages, reconnect | Direct event capture or native injection |

## Invariants

1. Exactly one physical owner per input session; a target does not spontaneously become a sender.
2. Never start suppressing physical-owner input until an authenticated target has granted and acknowledged an exclusive lease.
3. Every receiving input event is checked against authenticated source ID, session ID, epoch, sequence, protocol version and bounds.
4. On link loss or native failure: fail back to local input. Receiver attempts release of all injected pressed keys/buttons; failed releases must be retried and block new leases.
5. Native input callbacks never block on network, disk, UI or unbounded locks.
6. Packet order for key/button down/up is preserved; mouse movement coalescing must never cross a click, drag, handoff or release barrier.
7. Synthetic events must be explicitly identified to avoid capture/reinjection loops.
8. No logging of keys, clipboard contents, secret material or typed data.

## Coordinates

Topologies use **virtual logical points**, origin at upper-left, +Y downward, not framebuffer pixels. Each platform adapter must convert its own display coordinate system. Mapping policies across differently sized displays are explicit and covered by tests. A device may own multiple display nodes.

## Security boundaries

Peer discovery is **not authentication**. `PeerCompatibility.require` checks only version and capability support; it is not an authorization function. The `AuthorizedInputGate` expects source identity to be authenticated and the receiver lease to be approved by a separate transport/trust layer. None of those cryptographic prerequisites are implemented in Sprint 0; never expose the injection adapter over a socket until they are.

## Gating decisions

- **G0:** Native `CGEventTap` and Quartz injector compile and work under user-granted permissions on actual macOS devices; complete a two-Mac handoff with reliable local recovery.
- **G1:** Identity and mTLS pairing; negative-security integration tests on two actual peers.
- **G2:** Three-Mac topology, cross-resolution navigation and stress tests.
- **G3:** Signed/notarized beta app; OS matrix, fault injection, traceable perf evidence.

All gates remain **open** until actual evidence is attached.
