# InputMesh

**One input. Every desktop.** A local-first, peer-to-peer control plane intended to share one physical keyboard and pointer across multiple independent computers.

> **Development status — 2026-10-20: Sprint 0 / native feasibility. NOT a functioning cross-device controller.**
> The first supported adapter is planned for **macOS ↔ macOS**. Windows and Linux are architectural targets, not supported applications today.
> Pure Swift core and adapter contracts run in Linux unit tests; Quartz native APIs and real two-Mac control **have not been verified on macOS hardware**.

## Product roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 — macOS native feasibility | Capture, injection, cursor handoff, fail-back on two actual Macs | In progress; physical gate outstanding |
| 1 — input reliability | Pressed-input safety, filtering, local recovery, performance | Not started |
| 2 — secure peer sessions | Bonjour, explicit pairing, authenticated transport, leases | Not started |
| 3 — multiple Macs | A ↔ B ↔ C display topology, device settings | Not started |
| 4 — UX & beta | Menu bar app, permissions, signing, regression | Not started |
| Future | Windows/Linux native adapters and interop | Design only; not promised for a specific release |

## Implemented today

- OS-neutral virtual-display topology with edge handoff calculations in logical point coordinates.
- Deterministic input session states: LOCAL → SWITCHING → REMOTE → RECOVERING → LOCAL.
- Ack-gated remote routing (the state model only; no active network session yet).
- Pressed key/button tracking and a receiver-side gate: source/lease/sequence validation, limited input bounds, pending-release retry after injection errors. **These are layered checks, not a substitute for cryptographic authentication.**
- Bounded, versioned JSON frame codec for development; no production wire transport.
- OS/capability descriptor and platform-neutral input/permission/display interfaces in `InputMeshPlatform`.
- macOS Quartz **passive** event probe (event counters only) and a single-host input-injection adapter, both **unverified on macOS**.
- Portable Swift tests, CI job definitions and documented acceptance criteria.

## Not implemented

- No peer discovery, pairing, mTLS, socket transport, input routing over a network or clipboard synchronization.
- No active event suppression, robust cursor transfer, system-menu app, installer, Windows/Linux binary or notarization.
- No real macOS proof of input capture, suppression, injection or physical-device latency.

## Source layout

```text
Sources/
  InputMeshCore/          # Portable Swift: state, geometry, framing, peer capability model
  InputMeshPlatform/      # OS-independent input/permission/display adapter contracts
  InputMeshMacOS/         # Quartz-based probe/injection; macOS-specific
  InputMeshCLI/           # Sprint 0 diagnostics entry point
Tests/
  InputMeshCoreTests/
  InputMeshPlatformTests/
docs/
  architecture.md
  cross-platform.md
  security.md
  test-plan.md
  roadmap.md
```

Future `InputMeshWindows`/`InputMeshLinux` adapters must satisfy the same contracts. A shared Go transport/control service remains an **architecture option for later networking sprints**, not shipped code. No transport or input protocol compatibility with other projects is implied.

## Build and tests

Requires Swift 6.2.1+ (current package language mode is Swift 5 for compatibility), macOS 13+ for native functionality.

```sh
swift build
swift test --parallel
swift build -c release
swift run inputmesh --help
```

On an actual Mac, after granting any OS-required permissions to the executable host process:

```sh
swift run inputmesh --doctor
swift run inputmesh --probe
```

`--probe` is **passive**. It prints aggregate event counts periodically; it does not log key values, screen coordinates, typed text, send packets, suppress input or inject events.

## Security constraints

No root, no SIP bypass, no cloud requirement, no logging of input contents. Never accept remote input from an unpaired peer or use an unsecured plaintext transport to demo remote control. For actual release, authentication, per-session leases and physical fail-safe recovery are mandatory. See [threat model](docs/security.md).

## Contributing and release status

Read [contributing](CONTRIBUTING.md), [architecture](docs/architecture.md), [cross-platform contract](docs/cross-platform.md), [test plan](docs/test-plan.md), and [roadmap](docs/roadmap.md).

**Repository hosting:** Local Git repository exists. The connected GitHub tool cannot create a new repository. The proposed destination is `truongbo17/inputmesh` (private); no GitHub upload is claimed until that repository exists and a push succeeds.
