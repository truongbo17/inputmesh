# Verification matrix — InputMesh

## Portable automated tests (Linux executed)

- Geometry: 3-screen chain, vertical movement, gaps, invalid rectangles, overflow guards.
- Session: stale acknowledgement rejection, local fail-back and epoch advancement.
- Input correctness: pressed state and deterministic key/button release.
- Frame decoding: fragmentation, oversized frames, invalid JSON, bounded chunks.
- Security model: source/session/epoch/sequence replay guard and capability/version mismatch.
- Platform abstraction: authorized receiver gate, invalid sender rejection, revocation,
  injection failure, retry of failed key releases, unbounded motion rejection.

Run `swift test --parallel` on Linux. A green test does **not** prove that native macOS APIs work.

## Required physical macOS tests — NOT RUN

| ID | Scenario | Evidence needed |
|---|---|---|
| N01 | Accessibility / Input Monitoring permissions | System version, signing mode, anonymized screenshot |
| N02 | Quartz passive capture | Aggregate count diagnostics (never keys/text) |
| N03 | Local injection in disposable user account | Video without secrets and log of OS version |
| N04 | Active suppression / emergency local takeover | Recorded fault scenario and reproducible steps |
| N05 | Secure two-Mac authenticated input | Pairing validation / negative test trace |
| N06 | 3 real Macs, different resolutions | Video and topology configuration |
| N07 | Trackpad, Retina and external displays | Test matrix |
| N08 | Wi-Fi loss, sleep, app kill, permission loss | Recovery trace and no-stuck-key evidence |
| N09 | Untrusted and replayed input | Strict rejection confirmation |
| N10 | p95 latency, CPU / resident memory | Raw data, clock methodology and build SHA |

## Targets (not measured results)

- Capture-to-injection p95 <20 ms under a stable LAN with an appropriate timing method.
- Edge-crossing-to-first-target-input p95 <100 ms.
- Zero stuck inputs during the defined fault-injection suite.
- Idle CPU <2% of a core, resident memory <150 MB per app on representative hardware.
- 3 physical Macs before claiming multi-Mac MVP; simulation is supplemental.

## CI

- `swift build`, `swift test --parallel`, `swift build -c release` on Linux.
- The same SwiftPM commands on a macOS runner (native compile verification only).
- A macOS CI runner does not grant Accessibility permissions for UI automation by default.
- Developer ID, Hardened Runtime, notarization and installer tests are deferred.
