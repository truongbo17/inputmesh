# Physical two-Mac acceptance protocol — UNSATISFIED

This is a test procedure and evidence template, **not a report of tests that have happened**. GitHub Actions loopback testing cannot substitute for two independent physical Macs.

## Environment to record

| Attribute | Mac A | Mac B |
|---|---|---|
| Model / CPU | TODO | TODO |
| macOS version | TODO | TODO |
| App commit / code signature | TODO | TODO |
| LAN/Wi-Fi segment | TODO | TODO |

## Checklist

1. Obtain matching preview ZIP for CPU architecture, verify SHA256, identify that bundle is ad-hoc signed (not notarized). Do not install with elevated privileges.
2. On Mac B choose **Experimental Secure LAN Handoff** → **Accept connection for 2 minutes**; record exact TCP port 48437 and local IP.
3. On Mac A open the same beta window, enter Mac B's local IP and Connect. No listener is running before the action; confirm local-network permission dialogue is understandable.
4. Compare the generated SAS *out of band* on the two screens; deliberately reject an unexpected / mismatched code. Never test with actual passwords, tokens or private repos.
5. Approve on one Mac only and prove neither side receives a manifest yet; then approve independently on the other and verify both report mutually authenticated state.
6. Prepare separate clones of the **same synthetic test repo** with identical origin, branch and commit. Send from A; B should display origin/branch/SHA as inert data, without opening apps automatically.
7. B selects an existing clean clone; assert exact SHA match; choose Continue to explicitly open local VS Code.
8. Modify destination source file, add untracked file, switch branch and change SHA separately. Each variant MUST block editor launch; verify Git diff/status unchanged by InputMesh.
9. Revoke peer while connected; confirm crypto channel rejects further data and TCP session closes. Repeat after Wi-Fi drop, Mac sleep/wake, app restart and stale/disconnected peer.
10. Attempt malformed/oversized wire frames, replayed cipher frames, forged proof and unexpected incoming connection. Verify fail-closed behavior, no credential logging or background listener.
11. Run tests across Apple Silicon / Intel and declared macOS versions; record p50/p95 handoff time, reconnect, CPU/RAM and any crashes.
12. Verify VoiceOver, keyboard navigation, light/dark mode and screenshot provenance (physical model, OS, commit, date).

## Evidence policy

For each case store timestamp, device matrix, expected/actual result, issue URL, minimal sanitized logs, relevant screenshot/video and reviewer. Do not include key presses, tokens, source files or sensitive device identifiers. Close #24 only with physical evidence; not with simulated checks or green CI.
