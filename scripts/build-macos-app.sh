#!/usr/bin/env bash
# Builds a native InputMesh .app and a ZIP per host architecture; macOS only.
# Never claims a Developer ID signature unless a valid identity is supplied.
set -euo pipefail
[[ "$(uname -s)" == "Darwin" ]] || { echo 'ERROR: macOS required' >&2; exit 2; }
cd "$(dirname "$0")/.."
VERSION="${INPUTMESH_VERSION:-0.1.0}"
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
ARCH="$(uname -m)"
DIST="${INPUTMESH_DIST:-$PWD/dist}"
mkdir -p "$DIST"

swift build -c release --product InputMeshDesktop
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$DIST/InputMesh.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/InputMeshDesktop" "$APP/Contents/MacOS/InputMesh"
chmod +x "$APP/Contents/MacOS/InputMesh"

/usr/bin/python3 - "$APP/Contents/Info.plist" "$VERSION" "$BUILD_NUMBER" <<'PY'
import plistlib, sys
plist = {
    'CFBundleDevelopmentRegion':'en',
    'CFBundleDisplayName':'InputMesh',
    'CFBundleExecutable':'InputMesh',
    'CFBundleIdentifier':'dev.inputmesh.desktop',
    'CFBundleInfoDictionaryVersion':'6.0',
    'CFBundleName':'InputMesh',
    'CFBundlePackageType':'APPL',
    'CFBundleShortVersionString':sys.argv[2],
    'CFBundleVersion':sys.argv[3],
    'CFBundleIconFile':'InputMesh.icns',
    'LSMinimumSystemVersion':'13.0',
    'NSHighResolutionCapable':True,
    'LSApplicationCategoryType':'public.app-category.utilities',
    'NSHumanReadableCopyright':'Copyright 2026 InputMesh contributors',
}
with open(sys.argv[1], 'wb') as f: plistlib.dump(plist, f)
PY

ICONSET="$DIST/InputMesh.iconset"
mkdir -p "$ICONSET"
for px in 16 32 64 128 256 512 1024; do
    sips -s format png -z "$px" "$px" assets/brand/inputmesh-icon-1024.png --out "$DIST/icon-$px.png" >/dev/null
done
cp "$DIST/icon-16.png" "$ICONSET/icon_16x16.png"
cp "$DIST/icon-32.png" "$ICONSET/icon_16x16@2x.png"
cp "$DIST/icon-32.png" "$ICONSET/icon_32x32.png"
cp "$DIST/icon-64.png" "$ICONSET/icon_32x32@2x.png"
cp "$DIST/icon-128.png" "$ICONSET/icon_128x128.png"
cp "$DIST/icon-256.png" "$ICONSET/icon_128x128@2x.png"
cp "$DIST/icon-256.png" "$ICONSET/icon_256x256.png"
cp "$DIST/icon-512.png" "$ICONSET/icon_256x256@2x.png"
cp "$DIST/icon-512.png" "$ICONSET/icon_512x512.png"
cp "$DIST/icon-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/InputMesh.icns"
rm -rf "$ICONSET" "$DIST"/icon-*.png

if [[ -n "${INPUTMESH_SIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --timestamp --options runtime --sign "$INPUTMESH_SIGN_IDENTITY" "$APP"
    echo 'SIGNED_WITH_DEVELOPER_ID=true'
else
    codesign --force --deep --sign - "$APP"
    echo 'SIGNED_WITH_DEVELOPER_ID=false (ad-hoc CI preview; NOT notarized)'
fi
codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$APP/Contents/Info.plist"
file "$APP/Contents/MacOS/InputMesh"

ZIP="$DIST/InputMesh-${VERSION}-macos-${ARCH}-preview.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")") | tee "$ZIP.sha256"
echo "ARTIFACT=$ZIP"
