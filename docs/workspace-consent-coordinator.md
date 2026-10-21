# Workspace authenticated consent coordinator

Status: tested in-process on macOS GitHub Actions runners; not yet connected to Bonjour/NWConnection and not a user-facing network release.

The coordinator implements a full fail-closed *message processing* sequence:

1. Both sides independently send fresh signed-identity / ephemeral-key hello packets.
2. Each verifies the Ed25519 transcript proof, displays the same X25519-derived short authentication string (SAS), and requires explicit confirmation by a person on that machine.
3. Local confirmation encrypts a strict consent-accepted marker using a direction-specific ChaChaPoly channel tied to the signed handshake transcript. At most one early encrypted peer-acceptance packet may be queued before local confirmation.
4. Only after decrypting and validating the *other Mac's* acceptance does the local trust registry persist the verified peer signing key. The coordinator then permits sending or returning inert WorkspaceManifest metadata.
5. Any invalid wire phase, forged proof, invalid ciphertext, replay, untrusted/revoked peer or invalid manifest closes the logical session. No auto-execute, Git mutation or file synchronization path is introduced.

Tests run two coordinator instances with independent ephemeral device identities and memory-backed trust registries. They verify delayed confirmations, mutual consent, no early trust, signed proof rejection, replay/tamper, revocation and goodbye.

## Remaining P0 release gaps

- Connect this coordinator to a bounded, deadline-enforced Network.framework transport and Bonjour discovery without allowing a plaintext application command path.
- Guarantee serial event processing and cancel the physical connection when the peer is revoked; implement handshake timeouts, idle limits, reconnect and rate limiting.
- Native pairing/accept/revoke UX, Local Network permission onboarding and dedicated peer listener consent.
- Test on two physical Macs, verify malicious-peer and Wi-Fi failures, independent crypto/security audit.
- Developer ID signing, notarization, supported macOS runtime matrix and real UI screenshots.
