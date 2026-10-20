# InputMesh macOS UX specification

## Navigation

- **Overview:** local status, paired computers, device readiness; no fake connection status.
- **Devices:** trusted peers, explicit pairing, revocation (pairing is **not implemented** yet).
- **Screen Layout:** spatial display arrangement (editing is **not implemented** yet).
- **Security:** precise permission onboarding and protection state.
- **About:** development/status/version and repository links.

## Principles

1. **Honest statuses:** the development preview cannot pair/control another computer, so the UI always displays `Local` and indicates that pairing is unavailable.
2. **No silent permissions:** user action opens System Settings; the app cannot grant Accessibility or Input Monitoring itself.
3. **Fail open locally:** new network input functionality requires a verified, authenticated lease, and a physical escape path.
4. **Native conventions:** system SF Symbols, SwiftUI navigation, keyboard commands, dark mode and Dynamic Type-compatible body text.
5. **No keyboard event logging:** all key events and sensitive data are excluded from diagnostic telemetry.
6. **Accessible controls:** use native Button and Label, keyboard focus indicators, semantic grouping and VoiceOver labels.

## Design reference vs tested screenshot

`docs/assets/dashboard-design-preview.png` is an **HTML-rendered design reference** showing the intended visual hierarchy. It is NOT a screenshot of the SwiftUI `.app` on macOS. A genuine screenshot must be captured on a Mac after the native package passes CI, validated for light/dark mode, Retina, VoiceOver and screen sizes. Do not replace this limitation with generated visuals.

The native SwiftUI views are in `Sources/InputMeshDesktop`. Use the design preview to assess layout, not as release evidence.

## Release UX acceptance

- Supported 900×610 minimum window without clipping; 1024×768 and Retina checks.
- Light/dark themes, 125% text scaling and high-contrast checks.
- Keyboard-only navigation, VoiceOver, clear status of permissions and connection.
- No 'Connect' button until transport, cryptographic trust and exclusive leases exist.
- Screenshot from an actual macOS build with source commit, OS version, and date recorded.
