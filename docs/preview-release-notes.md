## ⚠️ InputMesh Workspace Handoff v0.3 beta — NOT a production release

This pre-release is an **ad-hoc signed diagnostic macOS app**, not a notarized or Developer ID-signed distribution. Gatekeeper may prevent launching a ZIP downloaded from GitHub. **Manual file-based Handoff remains available. Experimental encrypted Mac-to-Mac workspace metadata transfer is also available when both users explicitly start pairing, compare the same SAS and approve. No listener starts on app launch. No source files or unsaved edits are transferred.** Do not use it expecting a production-ready mouse/keyboard sharing application.

### Downloads

- `InputMesh-0.3.0-macos-arm64-preview.zip` — Apple Silicon (M1, M2, M3, M4 or newer arm64).
- `InputMesh-0.3.0-macos-x86_64-preview.zip` — Intel x86-64.
- Each ZIP has a matching `.sha256` checksum file.

Both files are produced by the macOS GitHub Actions native build matrix, with Swift unit tests, bundle/signature-integrity/arch checks. The declared minimum OS is macOS 13, but runtime compatibility still requires physical verification.

### Capabilities in this build

SwiftUI desktop dashboard, manual Git manifest import/export, opt-in manual-IP encrypted LAN pairing beta and safe conflict checks. Crypto/TCP integration has CI loopback evidence only. There is no automatic Bonjour discovery, arbitrary remote command, clipboard sync, mouse sharing or code-file transfer.

### Production release prerequisites

Real-device two-Mac *workspace* handoff and safe recovery; authenticated encrypted mutual consent, peer revocation/DoS review; macOS version/regression matrix; native UI/accessibility QA; Developer ID signature, notarization and Gatekeeper verification. Follow [docs/releasing.md](https://github.com/truongbo17/inputmesh/blob/main/docs/releasing.md) and [docs/test-plan.md](https://github.com/truongbo17/inputmesh/blob/main/docs/test-plan.md).


### Opt-in LAN pairing beta (not stable)

The native desktop beta now includes an experimental **manual-IP** encrypted peer session behind an explicit user action. Mac B starts a temporary listener, Mac A connects using its LAN IP, both users independently compare the transcript-derived SAS and approve, then transfer **Git metadata only**. The destination must select an existing clean clone and explicitly open the editor. No listener starts automatically and there is no Bonjour discovery or file/diff/unsaved-buffer sync. Native CI tests use two simulated peers over loopback; this does **not** constitute physical two-Mac certification. Do not expose the experimental listener on an untrusted network.
