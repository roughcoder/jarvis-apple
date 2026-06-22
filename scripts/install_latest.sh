#!/usr/bin/env bash
set -euo pipefail

PLACEHOLDER_REPO="__""REPOSITORY__"
DEFAULT_REPO="__REPOSITORY__"
REPO="${JARVIS_RELEASE_REPO:-${JARVIS_MENU_BAR_REPO:-$DEFAULT_REPO}}"
APP_NAME="Jarvis.app"
ASSET_NAME="Jarvis-macos.zip"
LEGACY_ASSET_NAME="JarvisMenuBar-macos.zip"

if [[ "$REPO" == "$PLACEHOLDER_REPO" || -z "$REPO" ]]; then
  echo "Set JARVIS_RELEASE_REPO=owner/repo before running this installer." >&2
  exit 2
fi

if [[ -n "${JARVIS_INSTALL_DIR:-}" ]]; then
  INSTALL_DIR="$JARVIS_INSTALL_DIR"
elif [[ -n "${JARVIS_MENU_BAR_INSTALL_DIR:-}" ]]; then
  INSTALL_DIR="$JARVIS_MENU_BAR_INSTALL_DIR"
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
LEGACY_URL="https://github.com/$REPO/releases/latest/download/$LEGACY_ASSET_NAME"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "Downloading $ASSET_NAME from $REPO with gh"
  if ! gh release download --repo "$REPO" --pattern "$ASSET_NAME" --dir "$TMP_DIR" --clobber; then
    echo "Falling back to legacy asset $LEGACY_ASSET_NAME"
    gh release download --repo "$REPO" --pattern "$LEGACY_ASSET_NAME" --dir "$TMP_DIR" --clobber
    ZIP_PATH="$TMP_DIR/$LEGACY_ASSET_NAME"
  fi
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "Downloading $ASSET_NAME from $REPO with GITHUB_TOKEN"
  ASSET_ID="$(/usr/bin/curl -fsSL \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/releases/latest" \
    | /usr/bin/python3 -c 'import json,sys; data=json.load(sys.stdin); names=("Jarvis-macos.zip","JarvisMenuBar-macos.zip"); print(next(a["id"] for a in data["assets"] if a["name"] in names))')"
  /usr/bin/curl -fL \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/octet-stream" \
    "https://api.github.com/repos/$REPO/releases/assets/$ASSET_ID" \
    -o "$ZIP_PATH"
else
  echo "Downloading $URL"
  if ! /usr/bin/curl -fL "$URL" -o "$ZIP_PATH"; then
    echo "Falling back to legacy asset $LEGACY_URL"
    ZIP_PATH="$TMP_DIR/$LEGACY_ASSET_NAME"
    /usr/bin/curl -fL "$LEGACY_URL" -o "$ZIP_PATH"
  fi
fi

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
/usr/bin/osascript -e 'tell application "Jarvis Menu Bar" to quit' >/dev/null 2>&1 || true

mkdir -p "$INSTALL_DIR"
echo "Using install directory $INSTALL_DIR"
echo "Installing to $INSTALL_DIR/$APP_NAME"
/usr/bin/ditto "$SOURCE_APP" "$INSTALL_DIR/$APP_NAME"

echo "Opening $APP_NAME"
/usr/bin/open "$INSTALL_DIR/$APP_NAME"
