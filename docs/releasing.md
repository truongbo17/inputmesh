# macOS release engineering

## Scope

- **Apple Silicon**: native `arm64` build on `macos-15` GitHub Actions.
- **Intel**: native `x86_64` build on `macos-15-intel` GitHub Actions.
- **Minimum target**: macOS Ventura 13; CI compilation on macOS 15 does NOT prove runtime compatibility with 13 or 14.
- **Preview**: app bundle wrapped in ZIP, ad-hoc signed. For engineering evaluation only; not Developer ID-signed or notarized. Gatekeeper may reject a downloaded preview.
- **Stable**: MUST be signed with an Apple Developer ID Application certificate and notarized, and must satisfy the physical two-Mac acceptance tests. GitHub Actions macOS runners cannot verify physical handoff or Accessibility decisions in a human user session.

## Build on Mac

```bash
swift test --parallel
./scripts/build-macos-app.sh
./scripts/verify-macos-app.sh dist/InputMesh.app "$(uname -m)"
```

Output: `dist/InputMesh-0.3.0-macos-{arm64|x86_64}-preview.zip`, matching SHA-256, plus `dist/InputMesh.app`.

## GitHub CI

Pull requests and main branch run Linux core tests and native macOS tests/builds for both CPU families. Download previews from the **Actions workflow artifacts** once all jobs are green. These artifacts are engineering previews, not endorsed production releases.

## Production release gate — Workspace Handoff

The release model is Sources/InputMeshCore/ReleaseGate.swift (schema 2). Every gate must have a **reviewable HTTPS evidence reference and human/CI verifier**, not just a boolean. This model is not a replacement for an independent security assessment or hardware evidence.

1. Linux core CI and independent native Apple Silicon / Intel build, test, ZIP architecture/checksum verification.
2. Two physical Macs demonstrate explicit identity pairing, *both* users approving the same authenticated SAS, encrypted mutual consent, replay/tamper rejection, trusted peer revocation and reconnection.
3. Two physical Macs demonstrate Mac A → Mac B Workspace Handoff, including clean and dirty branches, different commits, untracked files, disconnection, sleep/wake, reconnect and no unintended Git mutation.
4. An independent reviewer signs off on the threat model, audit of crypto transport and data/privacy controls. UI review includes real native screenshots, VoiceOver and local-network onboarding; support matrix checked at runtime on advertised macOS versions.
5. Code sign both app architectures with Developer ID Application identity and Hardened Runtime; notarize via xcrun notarytool; staple, validate and assess via spctl. Publish stable only after the signed artifact digest matches the audited build.

**Current state:** preview CI only. No real network pairing, physical two-Mac test evidence, third-party security review, Developer ID notarization or native-screenshot QA. Never mark stable until every release gate is backed by real evidence. CI samples that construct ReleaseEvidence use *synthetic* URLs and only test the invariant logic.

## Automatic development preview

Once CI jobs on main pass, the workflow publishes a GitHub pre-release named v0.3.0-preview.<run> with two macOS architecture ZIPs and SHA-256 files. Preview ZIPs are ad-hoc signed and not notarized.
