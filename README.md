# Jarvis

Native macOS app for observing and safely controlling local Jarvis roles.

The app intentionally shells out to the installed Jarvis checkout instead of embedding
Jarvis brain, intercom, worker, memory, gateway, or capability logic.

The current first surface is a menu bar operator panel. The product name is
broader on purpose: the same `.app` can grow into a full desktop chat and
operations UI without becoming a second macOS app.

## Project Identity

- App display name: `Jarvis`
- Swift package and executable product: `Jarvis`
- macOS bundle identifier: `dev.infinitestack.jarvis.mac`
- Future iOS bundle identifier: `dev.infinitestack.jarvis.ios`
- Release asset: `Jarvis-macos.zip`
- Release repository: `roughcoder/jarvis-apple`
- Homebrew tap: `roughcoder/homebrew-infinite-stack`
- Homebrew cask: `jarvis-app`

## Run

```bash
swift run Jarvis
```

Open Settings from the menu bar item and configure:

- Jarvis repo path
- `uv` binary path
- logs path
- installed roles on this Mac
- poll interval
- Docker checks
- app release repository, defaulting to `roughcoder/jarvis-apple`
- GitHub token for private-release checks, stored in Keychain

## Behavior

- Fast polling runs `uv run jarvis fleet-status --json --no-docker`.
- Full refreshes run `uv run jarvis fleet-status --json`.
- Local role controls use `launchctl` against `com.jarvis.brain`,
  `com.jarvis.intercom`, and `com.jarvis.worker`.
- Update is explicit and blocks when the Jarvis git working tree is dirty.
- Status JSON and command output are redacted before display or clipboard copy.
- App release checks read GitHub Releases and can install newer packaged app releases.
- If `jarvis-app` is installed with Homebrew, app release checks use Homebrew
  instead; the Upgrade button launches a detached Homebrew helper, quits Jarvis,
  upgrades the cask, and reopens the app.
- The Setup window installs selected local Jarvis services through the runtime
  CLI, issues per-device pairing entries, and keeps first-run setup out of raw
  terminal commands.
- The menu bar item uses an SF Symbols icon. The current symbol is `brain.head.profile`,
  configured in `AppIdentity.menuBarSymbolName`.

## Release Loop

Initialize the GitHub repository once, if you are starting from a fresh checkout:

```bash
git init -b main
git remote add origin git@github.com:roughcoder/jarvis-apple.git
git add Package.swift README.md Sources Tests scripts .gitignore
git commit -m "Establish Jarvis macOS release loop"
git push -u origin main
```

Build a local release artifact:

```bash
scripts/build_release.sh 0.1.0
```

This creates:

- `dist/Jarvis.app`
- `dist/Jarvis-macos.zip`
- `dist/Jarvis-macos.zip.sha256`

Create or update a GitHub Release and Homebrew cask:

```bash
scripts/release_github.sh 0.1.0
```

The release uploads the app zip, checksum, and `install_latest.sh` installer
asset, then updates `roughcoder/homebrew-infinite-stack/Casks/jarvis-app.rb`.
Draft releases skip Homebrew:

```bash
scripts/release_github.sh 0.1.0 --draft
```

If you need to publish a GitHub Release without touching Homebrew:

```bash
scripts/release_github.sh 0.1.0 --skip-homebrew
```

Public releases can install the latest app with:

```bash
curl -fsSL https://github.com/roughcoder/jarvis-apple/releases/latest/download/install_latest.sh | bash
```

Once installed as `Jarvis.app`, the menu can update itself from the App
Release section. It downloads the latest release zip, starts a detached installer
helper, quits the app, replaces the current `.app` bundle, and reopens the new
version. Self-update is disabled when running through `swift run`.

## Install And Self-Update Test

Use these steps on a second Mac.

Prerequisites:

- Public releases can be installed without a GitHub token.

Initial install:

```bash
curl -fsSL https://github.com/roughcoder/jarvis-apple/releases/latest/download/install_latest.sh | bash
```

The installer uses `/Applications` when it is writable. On managed laptops where
that path needs admin permission, it automatically installs to `~/Applications`.
Override the target when needed:

```bash
JARVIS_INSTALL_DIR="$HOME/Applications" bash /tmp/install_jarvis.sh
```

After the app opens:

1. Open the Jarvis menu bar item.
2. Open Settings.
3. Set `GitHub repo` to `roughcoder/jarvis-apple`.
4. Configure the Jarvis repo path, `uv` path, logs path, and installed roles for
   that Mac.
5. Close Settings.
6. Use App Release -> Check. On the current release, it should report up to date until a
   newer release exists.

Self-update test:

1. On the development Mac, commit any app change.
2. Publish a newer release:

   ```bash
   scripts/release_github.sh 0.2.3
   ```

3. On the second Mac, open the Jarvis menu bar item.
4. Use App Release -> Check.
5. Confirm it reports the new version is available.
6. Use App Release -> Install.
7. The app should quit, replace `/Applications/Jarvis.app`, and reopen.
8. Reopen the menu and confirm the App Release row shows the new current version.

If installation fails, the detached helper writes a temporary `install.log` under
`/tmp/JarvisUpdate-*` and shows a macOS notification with the log path.

## Homebrew Direction

The Homebrew tap can hold multiple Infinite Stack tools:

```bash
brew tap roughcoder/infinite-stack
brew install --HEAD jarvis
brew install --cask jarvis-app
xattr -dr com.apple.quarantine /Applications/Jarvis.app
brew update
brew upgrade jarvis
brew upgrade --cask jarvis-app
xattr -dr com.apple.quarantine /Applications/Jarvis.app
```

For normal releases, `scripts/release_github.sh <version>` updates the cask
after the GitHub release is published. Homebrew should own app updates on
machines installed with Homebrew. The in-app updater can remain for direct
installs, but Brew-managed installs should show update guidance instead of
replacing the `.app` bundle behind Brew's back.

The quarantine removal is needed while Jarvis is ad-hoc signed instead of
Developer ID signed and notarized.

## Test

```bash
swift test
```
