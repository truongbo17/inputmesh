# Workspace handoff threat model

## Trust boundaries

- User-selected local repo: not necessarily trustworthy. Git inspection runs a fixed list of Git subprocesses without shell interpolation; Git configuration itself is still a trust boundary.
- Manifest file: untrusted until checked; max 64KiB, schema version enforcement, credential-free HTTPS and SSH repository origin only, optional HTTPS resources only, no commands.
- Peer transport: **not available**; no new receiver or Bonjour listener installed by this change.
- Destination repository: user-selected existing tree; do not clone, reset, checkout, fetch, pull or merge.

## Threats, mitigations and residual risk

| Threat | Mitigation | Residual risk |
|---|---|---|
| Embedded password in Git remote | Reject URL userinfo and unsupported schemes | Git remote may be private even without secrets; metadata has disclosure risk |
| Malformed or huge manifest | Versioned Codable, manual invariants, 64KiB limit | Excessive JSON nesting inside size cap; fuzz on macOS recommended |
| Arbitrary shell execution from manifest | No shell, no user-provided command fields; `/usr/bin/open` with fixed app | Local editor plugins/workspace may execute code; opening untrusted workspaces is unsafe |
| Data loss from automatic branch switches | Read-only inspector, explicit blocker list, no `git checkout` | Human may manually override warnings |
| Dirty worktree and unsaved editor buffers | Dirty and untracked Git files block; unsaved buffers out of scope | Unsaved buffers cannot be detected reliably from Git |
| Malicious `git` in PATH | Fixed `/usr/bin/git` executable with FSMonitor/hooks disabled for inspection | PATH manipulation is an execution surface; hardened execution path is needed |
| Malicious Git config | Fixed subcommands; no repo mutation by application | Core Git configuration/extensions may run external helpers |
| Manifest MITM / modified source | Only import from known party using OS transfer | No cryptographic signature yet, trust cannot be proven automatically |

## Release requirements

Before a network release: signed binding to device identity, explicit pairing, AEAD/mTLS, replay prevention, trust revocation, malformed-payload fuzzing, App Transport Security review, Mac hardware permission QA. Until then, transfer manifest manually and verify repository identity in UI.
