#!/usr/bin/env bash
set -euo pipefail

PLACEHOLDER_REPO="__""REPOSITORY__"
DEFAULT_REPO="__REPOSITORY__"
REPO="${JARVIS_MENU_BAR_REPO:-$DEFAULT_REPO}"
INSTALL_DIR="${JARVIS_MENU_BAR_INSTALL_DIR:-/Applications}"
APP_NAME="Jarvis Menu Bar.app"
ASSET_NAME="JarvisMenuBar-macos.zip"

if [[ "$REPO" == "$PLACEHOLDER_REPO" || -z "$REPO" ]]; then
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

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "Downloading $ASSET_NAME from $REPO with gh"
  gh release download --repo "$REPO" --pattern "$ASSET_NAME" --dir "$TMP_DIR" --clobber
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "Downloading $ASSET_NAME from $REPO with GITHUB_TOKEN"
  ASSET_ID="$(/usr/bin/curl -fsSL \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/releases/latest" \
    | /usr/bin/python3 -c 'import json,sys; data=json.load(sys.stdin); print(next(a["id"] for a in data["assets"] if a["name"] == "JarvisMenuBar-macos.zip"))')"
  /usr/bin/curl -fL \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/octet-stream" \
    "https://api.github.com/repos/$REPO/releases/assets/$ASSET_ID" \
    -o "$ZIP_PATH"
else
  echo "Downloading $URL"
  /usr/bin/curl -fL "$URL" -o "$ZIP_PATH"
fi

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
