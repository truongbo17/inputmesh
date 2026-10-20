## ⚠️ Workspace Handoff developer preview — NOT a network handoff product

This pre-release is an **ad-hoc signed diagnostic macOS app**, not a notarized or Developer ID-signed distribution. Gatekeeper may prevent launching a ZIP downloaded from GitHub. **It cannot pair with, connect to or remotely control another Mac. It offers manual file-based Git workspace manifest capture, safe inspection and explicit VS Code open when repositories match. No source files or unsaved edits are transferred.** Do not use it expecting a production-ready mouse/keyboard sharing application.

### Downloads

- `InputMesh-0.2.0-macos-arm64-preview.zip` — Apple Silicon (M1, M2, M3, M4 or newer arm64).
- `InputMesh-0.2.0-macos-x86_64-preview.zip` — Intel x86-64.
- Each ZIP has a matching `.sha256` checksum file.

Both files are produced by the macOS GitHub Actions native build matrix, with Swift unit tests, bundle/signature-integrity/arch checks. The declared minimum OS is macOS 13, but runtime compatibility still requires physical verification.

### Capabilities in this build

SwiftUI desktop dashboard, menu bar, local diagnostics/permissions view, platform-neutral topology/session core, and a passive, non-recording Quartz diagnostic CLI. It includes local-only Workspace Handoff with a versioned, bounded JSON manifest. There is no network listener, device pairing, clipboard sync or mouse handoff.

### Production release prerequisites

Real-device two-Mac input handoff and safe recovery; authenticated encryption and pairing; security review; macOS version/regression matrix; Developer ID signature, notarization and Gatekeeper verification. Follow [docs/releasing.md](https://github.com/truongbo17/inputmesh/blob/main/docs/releasing.md) and [docs/test-plan.md](https://github.com/truongbo17/inputmesh/blob/main/docs/test-plan.md).
