# InputMesh comparative design review (2026-10-20)

Reference projects and product documentation:

- [Deskflow](https://github.com/deskflow/deskflow) (Synergy-compatible lineage): shows why the app and helper process need Accessibility permission and, on macOS 15, Local Network permission; exposes peer/layout workflows and clipboard support. **Learning:** the first-run permissions journey must be obvious. No Deskflow code is copied.
- [Lan Mouse](https://github.com/feschber/lan-mouse): Rust architecture with transport and platform integration. **Learning:** keep capture/injection adapters replaceable. No code imported.
- [Input Leap](https://github.com/input-leap/input-leap): open-source cross-machine input sharing. **Learning:** test host OS compatibility independently of core logic. No code imported.
- [Synergy](https://symless.com/synergy): paid keyboard/mouse sharing application. **Learning:** users expect stable reconnect, high-quality pointer handoff, clipboard and install packages; these are product goals rather than current capabilities.
- [Apple Universal Control](https://support.apple.com/en-us/102459): first-party experience baseline. **Learning:** auto handoff and clear device feedback matter; Apple's private platform integrations are not accessible through the public SDK.

## InputMesh differentiators to evaluate (not proven)

- Local-first, explicit consent and auditable trust/lease logic.
- Portable input protocol and OS-neutral topology, supporting Windows/Linux without rewriting routing logic.
- A macOS-native UI with straightforward permission onboarding.
- Measured end-to-end latency and fail-safe recovery gates before a stable release.

**Trademark warning:** before commercial use, check the InputMesh name for trademark and domain conflicts. Similar product names do not establish permission to use a brand.
