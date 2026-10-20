#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == "Darwin" ]] || { echo 'macOS required' >&2; exit 2; }
APP="${1:?Usage: verify-macos-app.sh /path/InputMesh.app arm64|x86_64}"
EXPECTED="${2:?Expected architecture required}"
[[ -d "$APP/Contents/MacOS" ]] || exit 3
[[ -x "$APP/Contents/MacOS/InputMesh" ]] || exit 4
plutil -lint "$APP/Contents/Info.plist"
ACTUAL=$(/usr/bin/python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'rb') as f: p=plistlib.load(f)
assert p['CFBundleIdentifier'] == 'dev.inputmesh.desktop', 'Wrong bundle ID'
assert p['CFBundleExecutable'] == 'InputMesh', 'Wrong executable'
assert p['LSMinimumSystemVersion'] == '13.0', 'Wrong deployment target'
print(p['CFBundleShortVersionString'])
PY
)
file "$APP/Contents/MacOS/InputMesh" | grep -q "$EXPECTED" || {
    echo "Binary does not have expected architecture: $EXPECTED" >&2; exit 5;
}
codesign --verify --deep --strict --verbose=2 "$APP"
[[ -s "$APP/Contents/Resources/InputMesh.icns" ]] || exit 6
echo "Verified InputMesh $ACTUAL for $EXPECTED (signature integrity only; NOT notarization)."
