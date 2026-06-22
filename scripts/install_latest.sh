#!/usr/bin/env bash
set -euo pipefail

REPO="${JARVIS_MENU_BAR_REPO:-__REPOSITORY__}"
INSTALL_DIR="${JARVIS_MENU_BAR_INSTALL_DIR:-/Applications}"
APP_NAME="Jarvis Menu Bar.app"
ASSET_NAME="JarvisMenuBar-macos.zip"

if [[ "$REPO" == "__REPOSITORY__" || -z "$REPO" ]]; then
  echo "Set JARVIS_MENU_BAR_REPO=owner/repo before running this installer." >&2
  exit 2
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ZIP_PATH="$TMP_DIR/$ASSET_NAME"
URL="https://github.com/$REPO/releases/latest/download/$ASSET_NAME"

echo "Downloading $URL"
/usr/bin/curl -fL "$URL" -o "$ZIP_PATH"

echo "Unpacking $APP_NAME"
/usr/bin/ditto -x -k "$ZIP_PATH" "$TMP_DIR"

if [[ ! -d "$TMP_DIR/$APP_NAME" ]]; then
  echo "Release asset did not contain $APP_NAME" >&2
  exit 1
fi

echo "Stopping existing app if needed"
/usr/bin/osascript -e 'tell application "Jarvis Menu Bar" to quit' >/dev/null 2>&1 || true

mkdir -p "$INSTALL_DIR"
echo "Installing to $INSTALL_DIR/$APP_NAME"
/usr/bin/ditto "$TMP_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME"

echo "Opening $APP_NAME"
/usr/bin/open "$INSTALL_DIR/$APP_NAME"
