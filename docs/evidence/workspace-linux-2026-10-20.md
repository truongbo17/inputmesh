# Workspace MVP evidence — Linux / Swift 6.2.1

This document covers *portable code and local Git tests only*. It is not evidence that a macOS GUI was manually operated or that two Mac computers paired.

## Environment

- Swift 6.2.1, Linux x86_64, git available at `/usr/bin/git`.
- Test commands: `swift build`, `swift test --parallel`, `swift build -c release`, `./scripts/test-workspace-handoff.sh`.

## Results

- Debug build: PASS.
- Portable XCTest: **34/34** PASS (includes tests from baseline source archive; CI may have additional tests in remote main).
- Optimized build: PASS.
- End-to-end CLI integration: PASS. Created an initial commit in source temp repo, cloned into separate destination, normalized configured origin, captured a manifest and inspected it successfully. Then changed a destination tracked file, confirmed exit code **3** and `destinationHasChanges` blocker, confirmed file remained changed.
- Additional negative tests include malformed manifest, invalid remote credentials, unsafe browser URL, commit/branch mismatch, case-sensitive repository mismatch and no source local paths in manifest.

## macOS gates still needed

- Native SwiftUI compilation/UI and CryptoKit identity negative tests via GitHub Actions.
- macOS Keychain persistence on user session, proper entitlements and access controls.
- Physical Mac→Mac AirDrop handoff; UI screenshot provenance; confirmed VS Code launch.
- Pairing authentication, encrypted channel and revocation; signed and notarized stable installer.

Never mark those gates passed on the basis of this Linux evidence.
