# InputMesh product roadmap — Cross-Device Workspace (2026-10-20)

**Decision:** stop competing with Deskflow as a mouse/keyboard sharing application. InputMesh concentrates on **Continue Workspace on Another Device**. Source packages from the original input-control spike are kept for reference, not presented as a production feature.

The sprints below have strictly ordered gates. Source written and green CI is not equivalent to a physical cross-Mac user journey.

## Sprint 1 — Trusted Device Foundation (PARTIAL; blocked for completion)

- [x] S1.1 Define trust boundaries, fingerprint and pairing strategy.
- [x] S1.2 Native CryptoKit Curve25519 identity, Keychain persistence module (source; macOS CI verification required).
- [x] S1.3 Signed challenge verification, deterministic human comparison code and negative cryptographic tests (source; CI verification required).
- [ ] S1.4 Bonjour discovery service and Local Network permission onboarding.
- [ ] S1.5 Bidirectional explicit user consent for identity pairing.
- [ ] S1.6 Bind peer public keys and proof-of-possession to end-to-end encrypted session, version/replay limits and revocation.
- [ ] S1.7 Physical test on **two Macs**: compare SAS out-of-band, accept/reject and revoke trust; verify unauthorized peer rejected.

**Exit gate:** authenticated and encrypted connection between two Macs, physically verified. Keychain identity/cryptography alone does NOT satisfy the gate.

## Sprint 2 — Workspace Context (portable implementation; physical acceptance pending)

- [x] S2.1 Portable, bounded and strictly validated manifest v1.
- [x] S2.2 Fixed-command read-only Git inspector detects origin, HEAD SHA, branch and dirtiness.
- [x] S2.3 Reject credential-bearing remotes, unsupported resources and oversized manifests.
- [x] S2.4 Block on source/destination dirty/untracked state, branch or SHA mismatch.
- [x] S2.5 Unit tests and real local Git-repo integration tests on Linux.
- [ ] S2.6 Physical Mac path/permission audit, nested worktrees, macOS case/Unicode/whitespace matrix.

**Exit gate:** pass on two real Mac Git clones with representative dirty/conflict states and no mutation. Green Linux CI alone is insufficient.

## Sprint 3 — Workspace Handoff (manual AirDrop/file preview; automatic one-click blocked)

- [x] S3.1 CLI `capture`, `inspect`, `continue` with explicit user intent and pre-open revalidation.
- [x] S3.2 Native SwiftUI handoff window, open/save pickers, manual AirDrop sharing and blocker view (source; macOS CI verification required).
- [x] S3.3 Local allowlisted VS Code launch (no remote-provided commands).
- [x] S3.4 End-to-end CLI smoke on two independent Git trees incl. conflict injection.
- [ ] S3.5 Physical A→B transfer using AirDrop, user confirmation and macOS screenshot provenance.
- [ ] S3.6 Automatic authenticated handoff over paired peer channel (depends Sprint 1).

**Exit gate:** complete transfer/open on two Macs and then authenticated remote handoff via Sprint 1. The preview is **not** production-grade one-click multi-device handoff.

## Sprint 4 — Production candidate

- [ ] Verify macOS arm64/Intel packaging, UX accessibility and OS-version regression on physical machines.
- [ ] Replace design mock with actual native SwiftUI screenshots in README.
- [ ] Developer ID code signing, notarization and Gatekeeper acceptance.
- [ ] Security assessment, data-loss regression, revocation, sleep/wake, Wi-Fi churn and end-to-end performance.
- [ ] Public beta only after Sprint 1/2/3 gates have genuine evidence.

## Out of scope for this roadmap

Remote input engine, arbitrary remote shell, unsaved buffer sync, automatic Git checkout/reset/pull, privileged services, production cloud services and general-purpose remote desktop.
