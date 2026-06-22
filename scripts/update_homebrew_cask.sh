#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/update_homebrew_cask.sh <version> [repository]

Updates, validates, commits, and pushes the Jarvis Homebrew cask after a
GitHub Release exists.

Environment:
  HOMEBREW_TAP_DIR=/path/to/homebrew-infinite-stack
  HOMEBREW_TAP_NAME=roughcoder/infinite-stack
  HOMEBREW_CASK_TOKEN=jarvis-app

Example:
  scripts/update_homebrew_cask.sh 0.2.3 roughcoder/jarvis-apple
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

VERSION="${1:-${VERSION:-}}"
REPOSITORY="${2:-${GITHUB_REPOSITORY:-roughcoder/jarvis-apple}}"
if [[ -z "$VERSION" ]]; then
  usage >&2
  exit 2
fi

VERSION="${VERSION#v}"
TAG="v$VERSION"
ASSET_NAME="${JARVIS_RELEASE_ASSET_NAME:-Jarvis-macos.zip}"
TAP_DIR="${HOMEBREW_TAP_DIR:-$HOME/Development/homebrew-infinite-stack}"
TAP_NAME="${HOMEBREW_TAP_NAME:-roughcoder/infinite-stack}"
CASK_TOKEN="${HOMEBREW_CASK_TOKEN:-jarvis-app}"
CASK_RELATIVE_PATH="Casks/$CASK_TOKEN.rb"
CASK_FILE="$TAP_DIR/$CASK_RELATIVE_PATH"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required: brew install gh" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to validate the cask." >&2
  exit 1
fi

gh auth status >/dev/null

if [[ ! -d "$TAP_DIR/.git" ]]; then
  echo "Homebrew tap checkout not found: $TAP_DIR" >&2
  exit 1
fi

if [[ ! -f "$CASK_FILE" ]]; then
  echo "Cask file not found: $CASK_FILE" >&2
  exit 1
fi

if [[ -n "$(git -C "$TAP_DIR" status --porcelain)" ]]; then
  echo "Homebrew tap has uncommitted changes. Commit or stash before updating:" >&2
  git -C "$TAP_DIR" status --short
  exit 1
fi

git -C "$TAP_DIR" pull --ff-only

ASSET_EXISTS="$(
  gh release view "$TAG" \
    --repo "$REPOSITORY" \
    --json assets \
    -q ".assets[] | select(.name == \"$ASSET_NAME\") | .name"
)"

if [[ -z "$ASSET_EXISTS" ]]; then
  echo "Release $TAG in $REPOSITORY does not include $ASSET_NAME." >&2
  exit 1
fi

SHA256="$(
  gh release download "$TAG" \
    --repo "$REPOSITORY" \
    --pattern "$ASSET_NAME.sha256" \
    --output - \
    2>/dev/null \
    | awk '{print $1}'
)"

if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Could not read a valid SHA-256 for $ASSET_NAME from $TAG." >&2
  exit 1
fi

CASK_FILE="$CASK_FILE" VERSION="$VERSION" SHA256="$SHA256" REPOSITORY="$REPOSITORY" ASSET_NAME="$ASSET_NAME" ruby <<'RUBY'
path = ENV.fetch("CASK_FILE")
version = ENV.fetch("VERSION")
sha256 = ENV.fetch("SHA256")
repository = ENV.fetch("REPOSITORY")
asset_name = ENV.fetch("ASSET_NAME")
public_url = "https://github.com/#{repository}/releases/download/v\#{version}/#{asset_name}"

text = File.read(path)

def replace!(text, pattern, replacement, label)
  replaced = text.sub!(pattern, replacement)
  abort "Could not update #{label} in #{ENV.fetch("CASK_FILE")}" unless replaced
end

replace!(text, /^  version "[^"]+"$/, %(  version "#{version}"), "version")
replace!(text, /^  sha256 "[0-9a-f]{64}"$/, %(  sha256 "#{sha256}"), "sha256")
lines = text.lines
url_index = lines.index { |line| line.match?(%r{^  url "https://(?:api\.)?github\.com/}) }
abort "Could not update url in #{path}" unless url_index

lines[url_index] = %(  url "#{public_url}"\n)
if lines[url_index + 1]&.start_with?("      header: [")
  close_index = (url_index + 1...lines.length).find { |index| lines[index].strip == "]" }
  abort "Could not remove legacy cask header block in #{path}" unless close_index
  lines.slice!(url_index + 1, close_index - url_index)
end
text = lines.join

File.write(path, text)
RUBY

CASK_CHANGED=0
if ! git -C "$TAP_DIR" diff --quiet -- "$CASK_RELATIVE_PATH"; then
  CASK_CHANGED=1
  git -C "$TAP_DIR" add "$CASK_RELATIVE_PATH"
  git -C "$TAP_DIR" commit -m "Update Jarvis app cask to $VERSION

Constraint: public Homebrew installs must not require GitHub API tokens
Rejected: use the GitHub release asset API URL | it keeps public installs coupled to private-release auth
Confidence: high
Scope-risk: narrow
Directive: update version, sha256, and public release download URL together for every Jarvis app release
Tested: brew style --cask $TAP_NAME/$CASK_TOKEN; brew audit --cask $TAP_NAME/$CASK_TOKEN; brew fetch --cask --force $TAP_NAME/$CASK_TOKEN
Not-tested: brew install --cask $CASK_TOKEN followed by quarantine removal"
else
  echo "$CASK_TOKEN is already up to date for $TAG."
fi

if ! brew --repo "$TAP_NAME" >/dev/null 2>&1; then
  brew tap "$TAP_NAME" "$TAP_DIR" --custom-remote
fi

BREW_TAP_REPO="$(brew --repo "$TAP_NAME")"
BREW_TAP_REMOTE="$(git -C "$BREW_TAP_REPO" remote get-url origin 2>/dev/null || true)"
if [[ "$BREW_TAP_REMOTE" != "$TAP_DIR" ]]; then
  git -C "$BREW_TAP_REPO" remote set-url origin "$TAP_DIR"
fi
git -C "$BREW_TAP_REPO" pull --ff-only

brew style --cask "$TAP_NAME/$CASK_TOKEN"
brew audit --cask "$TAP_NAME/$CASK_TOKEN"
brew fetch --cask --force "$TAP_NAME/$CASK_TOKEN"

if [[ "$CASK_CHANGED" -eq 1 ]]; then
  CURRENT_BRANCH="$(git -C "$TAP_DIR" branch --show-current)"
  git -C "$TAP_DIR" push origin "$CURRENT_BRANCH"
  echo "Updated $TAP_NAME/$CASK_TOKEN to $TAG."
else
  echo "Validated $TAP_NAME/$CASK_TOKEN for $TAG."
fi
