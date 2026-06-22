#!/usr/bin/env bash
set -euo pipefail

PLACEHOLDER_REPO="__""REPOSITORY__"
DEFAULT_REPO="__REPOSITORY__"
REPO="${JARVIS_RELEASE_REPO:-$DEFAULT_REPO}"
APP_NAME="Jarvis.app"
ASSET_NAME="Jarvis-macos.zip"

if [[ "$REPO" == "$PLACEHOLDER_REPO" || -z "$REPO" ]]; then
  echo "Set JARVIS_RELEASE_REPO=owner/repo before running this installer." >&2
  exit 2
fi

if [[ -n "${JARVIS_INSTALL_DIR:-}" ]]; then
  INSTALL_DIR="$JARVIS_INSTALL_DIR"
elif [[ -w "/Applications" ]]; then
  INSTALL_DIR="/Applications"
else
  INSTALL_DIR="$HOME/Applications"
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

SOURCE_APP="$TMP_DIR/$APP_NAME"
if [[ ! -d "$SOURCE_APP" ]]; then
  SOURCE_APP="$(/usr/bin/find "$TMP_DIR" -maxdepth 2 -name '*.app' -type d | /usr/bin/head -n 1)"
fi

if [[ -z "${SOURCE_APP:-}" || ! -d "$SOURCE_APP" ]]; then
  echo "Release asset did not contain $APP_NAME" >&2
  exit 1
fi

echo "Stopping existing app if needed"
/usr/bin/osascript -e 'tell application "Jarvis" to quit' >/dev/null 2>&1 || true

mkdir -p "$INSTALL_DIR"
echo "Using install directory $INSTALL_DIR"
echo "Installing to $INSTALL_DIR/$APP_NAME"
/usr/bin/ditto "$SOURCE_APP" "$INSTALL_DIR/$APP_NAME"

echo "Opening $APP_NAME"
/usr/bin/open "$INSTALL_DIR/$APP_NAME"
