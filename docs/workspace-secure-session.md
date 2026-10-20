# Workspace authenticated-session foundation

Status: **crypto primitives tested offline; NOT a network implementation or production-ready pairing.**

This module adds fresh per-connection ephemeral X25519 key agreement, signed/verified two-party transcript (Ed25519 identity from Keychain), independent HKDF-derived directional keys, 40-bit out-of-band short authentication string, single-use consent gate, and ChaCha20-Poly1305 messages bound to transcript and monotonic sequence. Frames are capped at 64 KiB; tamper, replay, out-of-order messages and role confusion are rejected.

## Threat boundary / required next work

The two computers must each display the same SAS and each person must explicitly confirm it. A session is not trusted merely because a signature verifies or a Bonjour service is discovered. Even after local confirmation, the network layer must exchange **encrypted, mutually acknowledged** acceptance messages before allowing workspace payloads.

Still missing: Bonjour discovery; network listener/client; wire length framing, deadlines and rate limits; Keychain trust registry/revoke; authenticated two-party consent protocol; physical two-Mac tests; threat-model review and independent security assessment. Do not expose these APIs as an unauthenticated remote service or publish as production.

No TCP server is introduced by this commit. A green macOS CI demonstrates primitive correctness only, not LAN/MITM resistance or user experience.
