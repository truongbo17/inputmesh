# Roadmap and issue decomposition — InputMesh

## Sprint 0 — Mac native feasibility (IN PROGRESS)

- [x] S0-01 Repository structure, portable Swift domain model and unit tests (Linux verified).
- [x] S0-02 Passive macOS event probe and Quartz injector **source written; Mac compile/use unverified**.
- [x] S0-03 GitHub Actions workflow file prepared (remote CI not executed).
- [x] S0-08 Rename MultiMac → InputMesh in new source, docs, CLI and SwiftPM targets.
- [x] S0-09 Introduce `InputMeshPlatform` contracts and capabilities for future OS adapters.
- [x] S0-10 Harden the local receiver gate, retry failed releases, and add unit tests (Linux verified).
- [ ] S0-04 Native macOS build, Accessibility / Input Monitoring diagnostics on a real Mac.
- [ ] S0-05 Single-host suppression and fail-safe return to local input.
- [ ] S0-06 Two actual Macs: pointer handoff, click and keyboard.
- [ ] S0-07 Benchmark p50/p95, input correctness and error-case evidence.

**Sprint 0 exit gate remains BLOCKED** without evidence from physical macOS hardware.

## Sprint 1 — Native input reliability (NOT STARTED)

- S1-01 Bounded nonblocking tap-to-worker queue, watchdog and error counters.
- S1-02 Synthetic event tagging / capture-loop prevention.
- S1-03 Relative pointer, warp, multiple displays and trackpad test matrix.
- S1-04 Native pressed-state release and failed-release recovery.
- S1-05 Panic hotkey, timeout, lock/sleep and permission-loss handling.

## Sprint 2 — Secure peer networking (NOT STARTED)

- S2-01 Bonjour discovery with manual-IP fallback and LAN permission onboarding.
- S2-02 Keychain device identity + explicit pairing ceremony.
- S2-03 Mutual TLS and trust revocation, no unauthenticated injection.
- S2-04 Single versioned wire schema, lease arbitration, heartbeat/replay verification.
- S2-05 Fail-safe Wi-Fi loss handling and security-negative tests.
- S2-06 Decide Go service boundary based on benchmark; no redundant network state machine.

## Sprint 3 — Multi-Mac topology (NOT STARTED)

- S3-01 Stable device/display IDs, monitor hotplug, DPI transforms.
- S3-02 A↔B↔C pointer, keyboard and remote-button state.
- S3-03 Topology editor and config migration.
- S3-04 Physical 3-Mac regression suite; 10-peer simulation is not physical certification.

## Sprint 4 — Desktop app and installer (NOT STARTED)

- S4-01 Signed macOS Menu Bar application.
- S4-02 Pairing UI, trusted devices, revoked trust, layout persistence.
- S4-03 Permission onboarding, safe autostart, packaged DMG.

## Sprint 5 — Production beta (NOT STARTED)

- S5-01 Full fault-injection and soak testing.
- S5-02 macOS hardware/OS version support matrix, p50/p95 and CPU/RSS.
- S5-03 Threat audit, code signing/notarization and release checklist.

## Future cross-platform adapters — after macOS baseline

- Windows adapter PoC and macOS ↔ Windows interoperability.
- Linux/X11 adapter PoC, Wayland limitations matrix, Linux ↔ macOS interoperability.
- Protocol compatibility, keyboard/HID translation, input-layout and multi-OS regression suite.

GitHub issues and PR tracking become possible when `truongbo17/inputmesh` repository is created. This local checkout has no GitHub remote yet.
