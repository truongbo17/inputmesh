# Workspace wire contract v1

Portable InputMeshWorkspace frames use a 4-byte unsigned big-endian length and a JSON envelope: version=1, kind=hello|proof|sealed|goodbye, payload=base64. No plaintext workspace manifest, URL opener or executable command kind exists.

- hello: public handshake offer, ≤4KiB (NOT trusted until Ed25519 proof).
- proof: signature, ≤512 bytes (cryptographic verification is a separate macOS adapter step).
- sealed: authenticated encrypted control/manifest bytes, maximum ciphertext of 64KiB + 36-byte sequence/nonce/tag overhead. Decryption MUST be performed before interpretation.
- goodbye: empty payload, closes connection.

Maximum encoded envelope 96KiB; each appended receive chunk maximum 256KiB. Decoder supports arbitrary byte fragmentation, multiple concatenated frames and immediately rejects oversized/malformed payloads. On any decode or state error the transport MUST close instead of trying to resynchronize on attacker bytes.

WorkspaceWirePolicy rejects a hello replay, early sealed payload and any manifest authorization before peer proof is verified, local user approves the transcript-derived short authentication string, and a separate **decrypted/authenticated peer consent ACK** is explicitly checked. Receiving a sealed frame is not proof of consent.

Important: this file is a transport/protocol foundation only. No Bonjour listener, NWConnection or cross-Mac handoff is enabled by this change. Production requires a real network controller, mutual authenticated acknowledgments, Keychain revocation integration, fault-injection tests, physical two-Mac acceptance and independent review.
