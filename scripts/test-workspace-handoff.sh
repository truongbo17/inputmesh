#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_BINARY="$ROOT/.build/debug/inputmesh"
[ -x "$SWIFT_BINARY" ] || { echo "ERROR: swift build first" >&2; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/source"
git -C "$TMP/source" init -q -b main
git -C "$TMP/source" config user.name Test
git -C "$TMP/source" config user.email test@example.com
git -C "$TMP/source" remote add origin https://github.com/example/demo.git
printf 'hello\n' > "$TMP/source/README.md"
git -C "$TMP/source" add README.md
git -C "$TMP/source" -c commit.gpgsign=false commit -qm init
git clone -q "$TMP/source" "$TMP/destination" # clone same SHA
# Local clone inherits local path as origin; replace it with canonical remote.
git -C "$TMP/destination" remote set-url origin https://github.com/example/demo.git
"$SWIFT_BINARY" workspace capture --repo "$TMP/source" --out "$TMP/transfer.json"
"$SWIFT_BINARY" workspace inspect --manifest "$TMP/transfer.json" --repo "$TMP/destination" | grep 'OK:'
printf 'dirty\n' >> "$TMP/destination/README.md"
set +e
"$SWIFT_BINARY" workspace inspect --manifest "$TMP/transfer.json" --repo "$TMP/destination" > "$TMP/output" 2>&1
RC=$?
set -e
[ "$RC" -eq 3 ] || { cat "$TMP/output" >&2; echo "Expected blocked status 3, got $RC" >&2; exit 1; }
grep 'destinationHasChanges' "$TMP/output"
# Ensure inspect never rewrites Git worktree.
grep 'dirty' "$TMP/destination/README.md" > /dev/null
echo 'InputMesh CLI end-to-end: PASS'
