## Summary

Describe behavior and modules changed.

## Design & safety impact

- [ ] No new unauthenticated input injection path
- [ ] Lease/session/epoch and local fail-back remain safe
- [ ] No keystrokes, text, clipboard values or secrets added to logging
- [ ] Cross-platform core remains free of OS-specific dependencies

## Validation

- [ ] `swift test --parallel` (attach result)
- [ ] `swift build -c release` (attach result)
- [ ] Native macOS test evidence when platform code changes (or mark blocked explicitly)

## Reproduction and rollback

Expected behavior, failure cases, rollback strategy.
