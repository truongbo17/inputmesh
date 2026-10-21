# InputMesh — Workspace Handoff roadmap

Scope: developer Git-context handoff across Macs, later Windows/Linux. The historic mouse/keyboard-sharing experiment is retired; Deskflow already serves that category.

## Sprint 1 — Trusted peer foundation (implementation partial, acceptance BLOCKED)

- [x] CryptoKit Ed25519 signing identity, device-local Keychain key storage, ephemeral X25519 agreement.
- [x] Transcript-bound signatures, SAS verification, HKDF directional keys, authenticated encryption, replay/order checks.
- [x] Deferred Keychain trust persistence until **both** sides approve and remote encrypted ACK verifies; active-channel revocation.
- [x] Bounded Network.framework TCP adapter; two independent peers exchange an encrypted inert manifest on *real localhost TCP* in macOS CI.
- [x] Experimental opt-in manual-IP pairing SwiftUI: temporary listener, user code comparison, source and destination confirmation.
- [ ] Bonjour discovery and accurate Local Network permissions onboarding across supported macOS versions.
- [ ] Admission/rate caps, network DoS/sleep/wake/reconnect recovery and cancel active socket on trust revocation.
- [ ] **Physical two-Mac acceptance** and external security audit.

Gate: remains **OPEN**. Successful loopback CI does not prove physical two-Mac pairing.

## Sprint 2 — Git workspace integrity (portable implementation complete, physical QA OPEN)

- [x] Versioned bounded JSON manifest, Git origin/branch/SHA and dirty/untracked state.
- [x] Reject credentialed remotes, unsupported resources, oversized files and distinct HTTPS ports.
- [x] Reject source/destination mismatch; no checkout/reset/pull/clone on behalf of user.
- [x] Revalidate existing destination and open an explicitly chosen local editor only on a clean exact match.
- [x] Linux/macOS unit tests and temporary Git working tree E2E smoke.
- [ ] Multiple physical Mac Git clones, Unicode/case/whitespace/worktrees and unsaved-editor UX QA.

## Sprint 3 — Workspace Handoff UI (manual and beta implemented, production gate OPEN)

- [x] Native SwiftUI local manifest export/import + manual AirDrop.
- [x] Optional encrypted manual-IP LAN handoff beta behind explicit two-sided approval.
- [x] Receiver reviews inert manifest metadata and selects existing clean destination; no automatic execution.
- [ ] Bonjour device selection and polished connect/revoke state UX.
- [ ] Real two-Mac A→B acceptance across Apple Silicon and Intel, Wi-Fi loss, sleep/wake and permissions.

## Sprint 4 — Production release (BLOCKED)

- [x] GitHub CI for Linux portable core and native macOS arm64/x86_64 packages.
- [ ] Independent threat-model/cryptography review, privacy and dependency audit.
- [ ] Real native UI screenshots, keyboard-only/VoiceOver and supported macOS runtime matrix.
- [ ] Developer ID Application signing, Hardened Runtime, notarization, Gatekeeper assessment and stapling.
- [ ] Hardware-soak evidence, reliability targets, honest release attestation per 13-gate Workspace release model.

Do NOT tag a stable release until all outstanding gates have reviewable evidence. Current versions are **ad-hoc-signed experimental previews** only.
