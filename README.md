# InputMesh

> **Continue your workspace on another device.** An open, local-first handoff tool for developers. The former cross-computer cursor concept is archived in history; Deskflow covers that market.

![InputMesh early design reference — not a screenshot of the running macOS application](docs/assets/dashboard-design-preview.png)

> **Visual status:** the image is an explicitly labeled **UI design reference** made from an HTML layout. The matching interface is implemented in SwiftUI, but no screenshot of the real macOS app has been validated yet. See [UX specification](docs/ui-ux.md).

## Project status · 20 October 2026 — Workspace Handoff preview

**Workspace Handoff developer preview.** This product transfers Git context manually via a JSON file, not mouse and keyboard input. It includes an experimental manual-IP encrypted LAN pairing workflow behind explicit two-sided human approval. The connection is tested on loopback only, **not certified between two physical Macs**. No listener starts automatically; a temporary one can be enabled in the beta window.

| Feature | Status |
|---|---|
| Git manifest capture/validation and conflict-safe local restore | Implemented, portable tests and local Git E2E |
| SwiftUI handoff and AirDrop/manual JSON transfer | Implemented, macOS CI build/tests; physical AirDrop QA pending |
| Authenticated session + Keychain peer trust | Crypto building blocks tested; **not wired to network** |
| Cross-platform workspace wire protocol | Implemented and tested; **no listener** |
| Native Apple Silicon + Intel preview packages | CI verified; ad-hoc signed, not notarized |
| Experimental manual-IP encrypted Mac pairing | Implemented in beta UI; CI loopback only, physical QA pending |
| Actual two physical Mac handoff / Bonjour discovery | Not verified / not implemented |
| macOS Developer ID signed stable release | Not implemented |


## Workspace Handoff (new product direction)

**Implemented:** Inspect an existing local Git repository, capture a minimal JSON manifest (origin/branch/commit + clean/dirty status), transfer JSON yourself (for example AirDrop), import it on another machine, compare the destination Git state and explicitly open Visual Studio Code **only when both copies are clean and at the same commit**. Nothing in Git is reset, pulled, checked out, cloned or overwritten. Unsaved editor buffers are **not transferred**.

**Partial security foundation:** native macOS identity generation, Keychain support and signed challenge primitives (not authenticated transport).

**Not implemented:** Bonjour peer discovery, hardware-certified automatic connection, synchronization of modified source files, background listener and fully automated one-click continuation. Manual-IP encrypted peer handoff exists as an experimental beta only. These remain separate production gates.

```bash
swift build && swift test --parallel
./scripts/test-workspace-handoff.sh
swift run inputmesh workspace capture --repo ~/code/project --out ~/Desktop/workspace.inputmesh.json
# AirDrop the JSON to the target Mac with the same Git clone/commit, then:
swift run inputmesh workspace inspect --manifest ~/Downloads/workspace.inputmesh.json --repo ~/code/project
swift run inputmesh workspace continue --manifest ~/Downloads/workspace.inputmesh.json --repo ~/code/project
```

The desktop application's **InputMesh > Open Workspace Handoff** menu opens a native SwiftUI workflow with system file/folder pickers and blocking-conflict explanations. Imported manifests contain source metadata and are **not signed or encrypted**; only import from trusted sources.

Read the [handoff specification](docs/workspace-handoff.md) and [threat model](docs/workspace-threat-model.md) before testing. **Do not treat an ad-hoc-signed preview as a stable installer.**

## Device support & packaging

| Architecture | GitHub Actions build | Minimum declared OS | Release quality |
|---|---|---|---|
| Apple Silicon (M1, M2, M3, M4 and later) `arm64` | `macos-15` | macOS 13 | Unnotarized preview, pending CI |
| Intel x86-64 `x86_64` | `macos-15-intel` | macOS 13 | Unnotarized preview, pending CI |

> The minimum macOS 13 deployment declaration is **not yet a runtime certification**. Actual macOS 13/14/15/26 compatibility needs testing. A production version will only ship after Developer ID signing, notarization and hands-on reliability/security testing.

## Building and trying the local diagnostic preview

Requires a Mac with Xcode CLI tools / Swift 6.2. On a Linux workstation only the platform-neutral core can build.

```bash
git clone https://github.com/truongbo17/inputmesh.git
cd inputmesh
swift test --parallel
./scripts/build-macos-app.sh
open dist/InputMesh.app
```

Workspace Handoff does not require Accessibility or Input Monitoring permissions. The legacy Quartz probe is a separate developer diagnostic; no permission needs to be granted to export/import a Git manifest. No listener starts by default; the experimental beta can open a temporary listener after explicit action. Its `inputmesh --probe` CLI reports counts, not typed keys or pointer coordinates.

Alternatively see [Releases](https://github.com/truongbo17/inputmesh/releases) for clearly marked developer previews, or [Actions](https://github.com/truongbo17/inputmesh/actions) for test reports and CI artifacts. The ZIP is ad-hoc signed, **not** Gatekeeper-notarized; it is not a user-facing stable installer.

## App navigation

- **Overview** — local Git handoff workflow and precise capability status.
- **Handoff Guide** — export, manual transfer, conflict inspection and explicit editor-open sequence.
- **Devices** — local Mac information; peer discovery unavailable in this preview.
- **Privacy & Security** — manifest data scope, local-only processing and no keyboard monitoring.
- **About** — development build status and repository information.

## Architecture

```text
Sources/
  InputMeshCore/         # Pure Swift algorithms, typed protocol models, release gate
  InputMeshWorkspace/    # Portable Git snapshot, manifest, conflicts and explicit handoff
  InputMeshPlatform/     # Cross-platform capture/inject/display/permission interfaces
  InputMeshMacOS/        # AppKit/Quartz display, capture diagnostic, input injector
  InputMeshCLI/          # Non-networked diagnostics
  InputMeshDesktop/      # Native SwiftUI desktop + macOS menu bar
Tests/
  InputMeshCoreTests/    # Linux and macOS portable tests
  InputMeshWorkspaceTests/ # Local Git repo and adversarial handoff tests
  InputMeshPlatformTests/
scripts/
  build-macos-app.sh     # Native arch build, .app, ad-hoc signature, ZIP, checksum
  verify-macos-app.sh    # Bundle/arch/signature verification (NOT notarization)
docs/
  ui-ux.md, architecture.md, security.md, cross-platform.md
  competitor-review.md, releasing.md, test-plan.md, roadmap.md
```

The portable Swift workspace core and native adapters are real code. No Go daemon or network listener is part of the current preview. No backend, tracking services or OS-level protection bypass are included.

## Security and release policy

No root or SIP bypass, key logging or unauthenticated remote actions. A legitimate Workspace Handoff release needs encrypted two-sided peer consent, revocation, conflict-safe Git state checks and physical two-Mac evidence. The [release evidence model](Sources/InputMeshCore/ReleaseGate.swift) deliberately fails until every gate is established. A green unit test does not prove Universal Control works.

- [Developer guide](CONTRIBUTING.md)
- [Native UX specification](docs/ui-ux.md)
- [Cross-platform architecture](docs/cross-platform.md)
- [Security threat model](docs/security.md)
- [Competitor research](docs/competitor-review.md)
- [macOS release engineering](docs/releasing.md)
- [Test plan](docs/test-plan.md)
- [Roadmap](docs/roadmap.md)

License, name availability and distribution strategy must be agreed before public commercialization. No license grant is implied by the repository being publicly visible.

## Physical QA before stable

The manual-IP beta has macOS CI and TCP loopback evidence, **not physical two-Mac certification**. Use [the two-Mac acceptance protocol](docs/physical-mac-acceptance.md) to record security, reliability and UX checks. Keep issues #24 (peer usability), #5 (native screenshots) and #4 (Developer ID signing/notarization) open until independently verified.
