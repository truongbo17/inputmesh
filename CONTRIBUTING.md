# Contributing to InputMesh

## Engineering workflow

- Keep `main` as the integration branch. Use `feat/<topic>`, `fix/<topic>`, `chore/<topic>` for development PRs.
- Include test results, risk analysis, rollback instructions and clear code-owner review before merge.
- A story is done only after required automated and physical-device evidence is attached.
- Do not mix cross-platform model changes with silent OS-only assumptions.
- Native macOS functionality must be compiled/tested on macOS hardware; a Linux test result is not sufficient.
- No password/keystroke/clipboard logging; do not add a remote injection socket without authentication, pairing and lease validation.

## Verify

```sh
swift build
swift test --parallel
swift build -c release
```

## Reporting

Do not submit unredacted user input or identity secrets to PRs, issues or test artifacts. See [docs/security.md](docs/security.md).
