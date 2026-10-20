# Workspace Handoff (product direction, 2026-10-20)

## Decision and competitor boundary

InputMesh is **not** rebuilding Deskflow/Synergy's keyboard/mouse-sharing engine.
InputMesh now focuses on user-initiated, cross-device developer *context handoff*.
- VS Code Settings Sync synchronizes profiles and settings; it does not guarantee two local Git trees have the same uncommitted work and commit.
- JetBrains Gateway is remote execution of an IDE on a host; InputMesh aims at resuming an **existing local clone** on a different host.
- Deskflow continues to be recommended for cross-computer pointer/keyboard sharing.

Primary user journey: **Choose repository -> capture only metadata -> transfer with AirDrop -> choose existing clone -> validate branch/commit/dirty state -> explicitly open VS Code.**

## Implemented local-first MVP (no encrypted network pairing yet)

`Sources/InputMeshWorkspace` (portable Swift domain / CLI) is deliberately independent of AppKit and CoreGraphics.

```text
InputMeshDesktop ──> InputMeshWorkspace ──> SystemGitRunner
   (SwiftUI)          (pure models)       (read-only Git inspection)
InputMeshCLI     ──> InputMeshWorkspace
```

Manifest version 1 only contains: version, creation time, non-secret origin URL, branch, commit SHA, uncommitted/untracked flags, optional HTTPS resource links (max 32). No file bodies, diffs, credentials, environment, uncommitted edits, terminal command or arbitrary URL schemes.

```text
Mac A                               Mac B
  ├─ choose Git repo                  ├─ import manifest (user picks file)
  ├─ git read-only metadata            ├─ choose already existing repo
  ├─ save .json                        ├─ re-inspect Git repository locally
  └── [AirDrop/manual transfer] ─────> ├─ calculate blocking conflicts
                                      ├─ explicitly confirm Continue
                                      └─ re-inspect and open VS Code locally
```

**Critical non-goals:** no repo clone/pull/fetch/reset/checkout, no implicit browser-opening on manifest import, no execution of manifest-supplied commands, no sync of unsaved editor buffers or secret-bearing remote URLs. `continue` requires exact normalized origin, branch and HEAD commit and *both worktrees clean*. Any mismatch blocks. If the user edits destination between preview and click, the app revalidates before opening. A truly concurrent file change can still occur between the final check and VS Code open; this workflow never modifies Git files.

### CLI smoke (portable; performed in CI)

```bash
swift build && swift test --parallel
./scripts/test-workspace-handoff.sh
swift run inputmesh workspace capture --repo ~/code/demo --out ~/Desktop/handoff.json
# Transfer JSON to second Mac with AirDrop; clone must exist there already.
swift run inputmesh workspace inspect --manifest ~/Downloads/handoff.json --repo ~/code/demo
swift run inputmesh workspace continue --manifest ~/Downloads/handoff.json --repo ~/code/demo
```

On macOS the native app opens a separate Workspace Handoff window through the InputMesh menu, with `NSSavePanel` and `NSOpenPanel`. It never opens peers automatically. Always inspect the origin and branch and only import manifests from trusted contacts. JSON is **not encrypted/signed**; do not put it on an untrusted channel.

## Three-stage plan, sequential evidence gates

| Stage | Deliverable | Automated gate | Physical gate |
|---|---|---|---|
| Sprint 1 · Device trust | Cross-platform trust policy and authenticated device discovery | Negative crypto/pairing/replay tests | Two Macs display matching verified identities, revoke peer | 
| Sprint 2 · Workspace | v1 portable manifest, real Git CLI capture, conflict-safe planner | Unit tests, malformed manifest and dirty repo tests | Git repos on both Macs with independent changes |
| Sprint 3 · Handoff | Import, inspect and explicit VS Code open | CLI end-to-end across two independent local clones; native macOS CI | Mac A sends to Mac B with user-selected AirDrop; verify editor launch |

**Status:** Sprint 2 *portable path implemented and Linux-tested*. Sprint 3 local file workflow *implemented pending macOS physical QA*. Sprint 1 network/pairing **not implemented**, so the one-click remote transport epic remains blocked. Do not label these sprints fully done without physical gate evidence.

### Later secure transport design (not shipped)

1. Bonjour advertises only opaque, non-sensitive peer metadata, never trust identity based on service name.
2. Device identity keys created in macOS Keychain, manually verified pairing fingerprints and consent on both sides.
3. Authenticated encrypted peer channel, explicit inbound handoff consent, versioned wire data, length/rate limits, nonce/replay defense, trust revocation.
4. Transfer only validated manifests, not executable instructions; choose existing clone and conflict-check on receiver.
5. Track last successful handoff and optional local audit without repository secrets.

Security, error states and hardware QA are release blockers, not backlog polish.
