#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/init_github_repo.sh owner/repo [--private|--public]

Initializes git if needed, creates the GitHub repository through gh, commits
the current source tree using the repo commit protocol, and pushes main.
USAGE
}

REPOSITORY="${1:-}"
VISIBILITY="${2:---private}"

if [[ -z "$REPOSITORY" || "$REPOSITORY" == "-h" || "$REPOSITORY" == "--help" ]]; then
  usage
  exit 2
fi

if [[ "$VISIBILITY" != "--private" && "$VISIBILITY" != "--public" ]]; then
  echo "Visibility must be --private or --public." >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required: brew install gh" >&2
  exit 1
fi

gh auth status >/dev/null

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init -b main
fi

git add Package.swift README.md Sources Tests scripts .gitignore

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  git commit -m "Establish Jarvis menu bar release loop

Constraint: local macOS distribution uses SwiftPM plus GitHub release assets
Confidence: high
Scope-risk: moderate
Directive: keep Jarvis service logic out of the menu bar app
Tested: swift test; swift build -c release
Not-tested: GitHub release publication before remote creation"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  if gh repo view "$REPOSITORY" >/dev/null 2>&1; then
    git remote add origin "git@github.com:$REPOSITORY.git"
    git push -u origin main
  else
    gh repo create "$REPOSITORY" "$VISIBILITY" --source=. --remote=origin --push
  fi
else
  git push -u origin main
fi
