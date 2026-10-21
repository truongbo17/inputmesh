# Native Network.framework TCP transport — engineering scope

WorkspaceTCPTransport drives the authenticated WorkspaceConsentCoordinator over real bounded TCP byte streams. It does not start any listener, authorize a peer or advertise Bonjour services automatically. Integrations must instantiate a user-enabled NWListener or explicit outgoing NWConnection and show the SAS to humans on both Macs.

The transport serializes all event handling, uses the portable length-framed WorkspaceWire codec, reads at most 16 KiB per socket callback, fails closed on decode/authentication errors or waiting/failed/cancelled connection state, enforces a 60-second pairing deadline and invalidates channels on close. Callbacks run on a transport queue and must be dispatched to main for SwiftUI.

Native CI exercises an actual Network.framework TCP loopback using two independent MacDeviceIdentity/WorkspaceConsentCoordinator instances, two separate in-memory trust stores, real fragmentable socket frames and validated encrypted manifest bytes. **The test fixture approves the SAS automatically solely to exercise the protocol; the actual application does NOT do this**.

## Production blockers

- No UI-driven two-Mac listener, Bonjour discovery or Local Network onboarding; no real physical A→B testing.
- No per-IP connection admission policy, peer concurrency limits, long-lived heartbeat/idle timer or OS sleep/wake recovery.
- Peer revocation must cancel active NWConnection as well as invalidating crypto state.
- Security review, runtime Mac version certification, Developer ID signing/notarization and accessibility QA remain mandatory.
