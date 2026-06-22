#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build_release.sh <version>

Builds a local macOS .app bundle and release zip under dist/.

Example:
  scripts/build_release.sh 0.1.0
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

VERSION="${1:-${VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  usage >&2
  exit 2
fi

VERSION="${VERSION#v}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Jarvis Menu Bar"
EXECUTABLE_NAME="JarvisMenuBar"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/JarvisMenuBar-macos.zip"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}"

cd "$ROOT_DIR"

swift test
swift build -c release --product "$EXECUTABLE_NAME"

rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp ".build/release/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.jarvis.menubar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR"
fi

(
  cd "$DIST_DIR"
  ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$ZIP_PATH").sha256"
)

cat > "$DIST_DIR/release-notes.md" <<NOTES
# Jarvis Menu Bar v$VERSION

Local macOS menu bar app for observing Jarvis roles and checking app releases.

## Install

Download \`JarvisMenuBar-macos.zip\`, unzip it, and move \`$APP_NAME.app\` to \`/Applications\`.

For scripted install, download the \`install_latest.sh\` release asset and run it:

\`\`\`bash
curl -fsSL https://github.com/roughcoder/jarvis-swift-toolbar/releases/latest/download/install_latest.sh | bash
\`\`\`
NOTES

echo "Built $ZIP_PATH"
echo "Checksum: $ZIP_PATH.sha256"
