# InputMesh native macOS Workspace Handoff UX

## Primary navigation

- **Overview:** start manual Git handoff; display actual local capability status, never fake paired devices.
- **Handoff Guide:** stepwise export, AirDrop transfer, validation and explicit local editor-open.
- **Devices:** local host only until authenticated LAN pairing exists.
- **Privacy & Security:** metadata exposure, no remote commands and no privileged keyboard monitoring.
- **About:** source, version and release quality.

## Permissions and consent

Workspace Handoff reads Git metadata only from a user-selected repository; it does **not** need Accessibility or Input Monitoring privileges. Historic passive input-probe diagnostics do not belong to product onboarding.

Exported JSON may expose confidential project names/remotes and is **not encrypted**. The user selects transfer method and destination clone. No automatic Git checkout, reset, pull, file transfer or arbitrary command is executed.

An authenticated network pairing UI must not become available until the entire mutual approval/revocation flow is backed by real hardware tests.

## Real native screenshot gate

The dashboard image in docs/assets/dashboard-design-preview.png is a historical design reference, not a screenshot of the installed native app. Issue #5 tracks a real Mac capture, light/dark mode, VoiceOver, keyboard-only navigation, 900×610 minimum dashboard, high-contrast and Retina checks. CI compilation alone is insufficient.

## Experimental LAN pairing window

Users explicitly start a 2-minute listener (TCP port 48437) on the receiving Mac; the sender enters its LAN IP. Each Mac independently displays a handshake-derived SAS and must be approved by a person; no code is automatically confirmed in the app. Only encrypted, validated Git manifest metadata is delivered and the receiving person must select an existing clone. A mismatched branch/SHA or dirty working tree blocks opening. There is no Bonjour discovery yet. Close/revoke must tear down the active transport; physical verification is pending.
