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

Output: `dist/InputMesh-0.1.0-macos-{arm64|x86_64}-preview.zip`, matching SHA-256, plus `dist/InputMesh.app`.

## GitHub CI

Pull requests and main branch run Linux core tests and native macOS tests/builds for both CPU families. Download previews from the **Actions workflow artifacts** once all jobs are green. These artifacts are engineering previews, not endorsed production releases.

## Production release gate

1. Pair two physical Macs, test pointer handoff, disconnect, sleep/wake, lost permission, keyboard key-up recovery and input source changes. Record host hardware, macOS versions, video/log evidence (never key contents), target latencies and repeat counts.
2. Have a reviewer validate the security threat model and exclusive input lease implementation.
3. Validate supported deployment targets on actual macOS 13, 14, 15 and 26 hosts (or narrow documented support).
4. Sign with a Developer ID Application certificate (CI keychain import from encrypted repository secrets), use Hardened Runtime, run `xcrun notarytool submit ... --wait`, staple and verify with `xcrun stapler validate` and `spctl --assess`.
5. Create a tagged GitHub release only after steps 1–4 pass. Retain checksum, provenance and test evidence.

**Not implemented yet:** automated Developer ID secret import, notarization and stable publish. The existence of a ZIP or GitHub CI green does NOT satisfy this gate. Never describe preview builds as notarized/production ready.

## Automatic development preview

Once all CI jobs on `main` succeed, the workflow publishes a GitHub **pre-release** named `v0.1.0-preview.<run>` containing the two macOS architecture ZIPs and checksums. It **does not** sign with a Developer ID or notarize anything. Only use these artifacts for development evaluation. This workflow is intentionally not called a stable release.
