# Security and privacy baseline

**Risk:** Input remoting is a high-trust capability. Treat captured keyboard and mouse data as highly sensitive.

## Assets

- Host keyboard/mouse control, typed secrets, clipboard, trusted peer identity, device keys, session tokens.

## Threats and required controls

| Threat | Required control | State |
|---|---|---|
| LAN host impersonates a Mac | Explicit pairing, authenticated peer identity, mutual TLS | NOT IMPLEMENTED |
| Session replay or packet reorder | Epoch, strict sequence, lease binding | Portable component unit-tested; not integrated |
| Unauthorized remote injection | Target-side authorization and exclusive input lease | NOT IMPLEMENTED |
| Event tap captures credentials | No payload logging, no cloud, no raw input persistence | Diagnostic probe counts only |
| Event loop/hijack | Synthetic-origin tagging + suppression guard + panic hotkey | NOT IMPLEMENTED |
| Stuck modifiers/buttons | Pressed-state tracker + release/reset | Portable component implemented, not wired to native |
| Denial of service by malformed frame | Max payload/chunk, framing validation | Unit-tested |
| Permission abuse | User-granted macOS permissions, narrow process privileges | Native diagnostics only |
| Untrusted screen/sleep transitions | Revoke leases on lock/logout/sleep/permissions change | NOT IMPLEMENTED |

No receiver, listener or input forwarding path is implemented in Sprint 0.
Do not substitute plaintext TCP for mTLS to demonstrate the product; a loopback-only in-process
PoC is permissible for native feasibility testing but must not be network-accessible.

## Future pairing requirements

- Device-generated identity keys stored in Keychain; user-verifiable out-of-band pairing.
- Certificate pinning/verified identity binding in mutual TLS 1.3.
- Device removal immediately invalidates trusted sessions.
- Authenticated source identity is independent from target device ID.
- Encrypt telemetry where needed, and never include raw key codes or strings in logs.

## Reporting

Report vulnerabilities privately to repo owners. Avoid attaching unredacted event captures.
