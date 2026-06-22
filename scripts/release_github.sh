#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/release_github.sh <version> [--draft]

Builds the macOS app locally, pushes the current branch and tag, then creates
or updates a GitHub Release with the app zip, checksum, and installer script.

Environment:
  GITHUB_REPOSITORY=owner/repo   Override repository detection.

Example:
  scripts/release_github.sh 0.1.0 --draft
  scripts/release_github.sh 0.1.0
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  usage >&2
  exit 2
fi
shift || true

DRAFT_FLAG=""
if [[ "${1:-}" == "--draft" ]]; then
  DRAFT_FLAG="--draft"
fi

VERSION="${VERSION#v}"
TAG="v$VERSION"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_NAME="Jarvis-macos.zip"
cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This directory is not a git repository. Run git init and add a GitHub remote first." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required: brew install gh" >&2
  exit 1
fi

gh auth status >/dev/null

REPOSITORY="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPOSITORY" ]]; then
  REPOSITORY="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [[ -z "$REPOSITORY" ]]; then
  echo "Could not detect GitHub repository. Set GITHUB_REPOSITORY=owner/repo." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain -- . ':(exclude)dist')" ]]; then
  echo "Working tree has uncommitted source changes. Commit or stash before releasing." >&2
  git status --short -- . ':(exclude)dist'
  exit 1
fi

"$ROOT_DIR/scripts/build_release.sh" "$VERSION"

sed "s#__REPOSITORY__#$REPOSITORY#g" "$ROOT_DIR/scripts/install_latest.sh" > "$ROOT_DIR/dist/install_latest.sh"
chmod +x "$ROOT_DIR/dist/install_latest.sh"

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -a "$TAG" -m "Release $TAG"
fi

CURRENT_BRANCH="$(git branch --show-current)"
git push origin "$CURRENT_BRANCH"
git push origin "$TAG"

if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$TAG" \
    "$ROOT_DIR/dist/$ASSET_NAME" \
    "$ROOT_DIR/dist/$ASSET_NAME.sha256" \
    "$ROOT_DIR/dist/install_latest.sh" \
    --repo "$REPOSITORY" \
    --clobber
else
  gh release create "$TAG" \
    "$ROOT_DIR/dist/$ASSET_NAME" \
    "$ROOT_DIR/dist/$ASSET_NAME.sha256" \
    "$ROOT_DIR/dist/install_latest.sh" \
    --repo "$REPOSITORY" \
    --title "Jarvis $TAG" \
    --notes-file "$ROOT_DIR/dist/release-notes.md" \
    $DRAFT_FLAG
fi

echo "Released $TAG to https://github.com/$REPOSITORY/releases/tag/$TAG"
