# Local trust lifecycle

The macOS trust registry persists **Ed25519 public keys only**, in a device-local Keychain item (WhenUnlockedThisDeviceOnly). The local Mac must receive an authenticated transcript and the user must explicitly compare the verified per-session short authentication string (SAS) before adding trust. No Bonjour name or IP address grants trust.

On revocation, every live channel created through WorkspacePeerTrustStore is invalidated and rejects further encryption/decryption. The network controller **must also cancel its NWConnection** and send no workspace data; the listener/connection manager does not exist yet. A Keychain write failure fails the current channel closed and is surfaced to the caller. Keychain-backed integration and physical two-Mac revocation tests remain pending.

CI uses an in-memory test persistence, never the runner's real login Keychain. Tests cover refusal of wrong SAS, trusted identity persistence, active-channel revocation, invalid key and failed persistent write. Production still blocked on authenticated network transport, mutually acknowledged consent, hardware QA, notarization and independent review.
