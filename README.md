# Jarvis Menu Bar

Native macOS menu bar app for observing and safely controlling local Jarvis roles.

The app intentionally shells out to the installed Jarvis checkout instead of embedding
Jarvis brain, intercom, worker, memory, gateway, or capability logic.

## Run

```bash
swift run JarvisMenuBar
```

Open Settings from the menu bar item and configure:

- Jarvis repo path
- `uv` binary path
- logs path
- installed roles on this Mac
- poll interval
- Docker checks
- app release repository, defaulting to `roughcoder/jarvis-swift-toolbar`
- GitHub token for private-release checks, stored in Keychain

## Behavior

- Fast polling runs `uv run jarvis fleet-status --json --no-docker`.
- Full refreshes run `uv run jarvis fleet-status --json`.
- Local role controls use `launchctl` against `com.jarvis.brain`,
  `com.jarvis.intercom`, and `com.jarvis.worker`.
- Update is explicit and blocks when the Jarvis git working tree is dirty.
- Status JSON and command output are redacted before display or clipboard copy.
- App release checks read GitHub Releases and download the packaged app asset.

## Release Loop

Initialize the GitHub repository once:

```bash
git init -b main
git remote add origin git@github.com:roughcoder/jarvis-swift-toolbar.git
git add Package.swift README.md Sources Tests scripts .gitignore
git commit -m "Establish Jarvis menu bar release loop"
git push -u origin main
```

Build a local release artifact:

```bash
scripts/build_release.sh 0.1.0
```

This creates:

- `dist/Jarvis Menu Bar.app`
- `dist/JarvisMenuBar-macos.zip`
- `dist/JarvisMenuBar-macos.zip.sha256`

Create or update a GitHub Release:

```bash
scripts/release_github.sh 0.1.0 --draft
```

Remove `--draft` when you want the release visible. The release uploads the app
zip, checksum, and `install_latest.sh` installer asset.

For this private repository, authenticated installs can use `gh`:

```bash
gh release download --repo roughcoder/jarvis-swift-toolbar --pattern install_latest.sh --output /tmp/install_jarvis_menu_bar.sh
bash /tmp/install_jarvis_menu_bar.sh
```

Public repositories can also install the latest release with:

```bash
curl -fsSL https://github.com/roughcoder/jarvis-swift-toolbar/releases/latest/download/install_latest.sh | bash
```

## Test

```bash
swift test
```
