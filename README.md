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
- App release checks read GitHub Releases and can install newer packaged app releases.

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

Once installed as `Jarvis Menu Bar.app`, the menu can update itself from the App
Release section. It downloads the latest release zip, starts a detached installer
helper, quits the app, replaces the current `.app` bundle, and reopens the new
version. Self-update is disabled when running through `swift run`.

## Install And Self-Update Test

Use these steps on a second Mac.

Prerequisites:

- GitHub CLI installed: `brew install gh`
- Authenticated GitHub CLI session with access to `roughcoder/jarvis-swift-toolbar`:
  `gh auth login`
- A GitHub token with private repository release read access, for the app's
  Settings window. Fine-grained tokens should allow contents/repository metadata
  read access for this repository.

Initial install:

```bash
tmpdir=$(mktemp -d)
gh release download v0.1.2 --repo roughcoder/jarvis-swift-toolbar --pattern install_latest.sh --dir "$tmpdir"
bash "$tmpdir/install_latest.sh"
```

The installer uses `/Applications` when it is writable. On managed laptops where
that path needs admin permission, it automatically installs to `~/Applications`.
Override the target when needed:

```bash
JARVIS_MENU_BAR_INSTALL_DIR="$HOME/Applications" bash "$tmpdir/install_latest.sh"
```

After the app opens:

1. Open the Jarvis menu bar item.
2. Open Settings.
3. Set `GitHub repo` to `roughcoder/jarvis-swift-toolbar`.
4. Paste the GitHub token into `GitHub token for private releases`.
5. Configure the Jarvis repo path, `uv` path, logs path, and installed roles for
   that Mac.
6. Close Settings.
7. Use App Release -> Check. On `v0.1.2`, it should report up to date until a
   newer release exists.

Self-update test:

1. On the development Mac, commit any app change.
2. Publish a newer release:

   ```bash
   scripts/release_github.sh 0.1.3
   ```

3. On the second Mac, open the Jarvis menu bar item.
4. Use App Release -> Check.
5. Confirm it reports `v0.1.3 available`.
6. Use App Release -> Install.
7. The app should quit, replace `/Applications/Jarvis Menu Bar.app`, and reopen.
8. Reopen the menu and confirm the App Release row shows current `0.1.3`.

If installation fails, the detached helper writes a temporary `install.log` under
`/tmp/JarvisMenuBarUpdate-*` and shows a macOS notification with the log path.

## Test

```bash
swift test
```
