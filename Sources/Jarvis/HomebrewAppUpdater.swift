import AppKit
import Foundation

enum HomebrewAppUpdaterError: LocalizedError {
    case notRunningFromAppBundle
    case brewNotFound
    case helperLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            return "Homebrew update requires running from the packaged \(AppIdentity.displayName).app bundle."
        case .brewNotFound:
            return "Homebrew was not found at /opt/homebrew/bin/brew or /usr/local/bin/brew."
        case .helperLaunchFailed(let message):
            return "Could not start the Homebrew updater: \(message)"
        }
    }
}

struct HomebrewAppUpdater {
    func upgradeInstalledCask(
        status: HomebrewCaskStatus,
        bundleURL: URL? = AppReleaseInstaller.currentAppBundleURL(),
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) throws {
        guard let bundleURL else {
            throw HomebrewAppUpdaterError.notRunningFromAppBundle
        }
        guard let brewPath = HomebrewReleaseClient.defaultBrewPath() else {
            throw HomebrewAppUpdaterError.brewNotFound
        }

        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("\(AppIdentity.executableName)BrewUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        let helperURL = workDirectory.appendingPathComponent("brew_update.sh")
        try Self.helperScript.write(to: helperURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            helperURL.path,
            brewPath,
            Self.defaultGitHubCLIPath() ?? "",
            status.token,
            AppIdentity.homebrewTap,
            AppIdentity.displayName,
            String(processIdentifier),
            workDirectory.path,
            bundleURL.path
        ]

        do {
            try process.run()
        } catch {
            throw HomebrewAppUpdaterError.helperLaunchFailed(error.localizedDescription)
        }
    }

    static func defaultGitHubCLIPath(fileManager: FileManager = .default) -> String? {
        [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh"
        ].first { fileManager.isExecutableFile(atPath: $0) }
    }

    static let helperScript = """
    #!/usr/bin/env bash
    set -euo pipefail

    BREW_PATH="$1"
    GH_PATH="$2"
    CASK_TOKEN="$3"
    TAP_NAME="$4"
    APP_NAME="$5"
    APP_PID="$6"
    WORK_DIR="$7"
    TARGET_APP="$8"
    LOG_PATH="$WORK_DIR/homebrew-update.log"

    mkdir -p "$WORK_DIR"
    exec >> "$LOG_PATH" 2>&1

    notify_failure() {
      /usr/bin/osascript -e "display notification \\"Homebrew update failed. See $LOG_PATH\\" with title \\"Jarvis\\"" >/dev/null 2>&1 || true
    }
    trap notify_failure ERR

    echo "Preparing Homebrew update for $CASK_TOKEN"
    TOKEN="${HOMEBREW_GITHUB_API_TOKEN:-}"
    if [[ -z "$TOKEN" && -n "$GH_PATH" && -x "$GH_PATH" ]]; then
      TOKEN="$("$GH_PATH" auth token 2>/dev/null || true)"
    fi
    if [[ -z "$TOKEN" ]]; then
      echo "No GitHub token found. Run gh auth login, or set HOMEBREW_GITHUB_API_TOKEN before launching Jarvis."
      exit 1
    fi
    export HOMEBREW_GITHUB_API_TOKEN="$TOKEN"

    echo "Trusting tap $TAP_NAME"
    "$BREW_PATH" trust --tap "$TAP_NAME" || true

    echo "Updating Homebrew metadata"
    "$BREW_PATH" update

    echo "Waiting for app process $APP_PID to exit"
    for _ in {1..100}; do
      if ! /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
        break
      fi
      /bin/sleep 0.2
    done

    if /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
      echo "App process still running; asking it to quit"
      /usr/bin/osascript -e "tell application \\"$APP_NAME\\" to quit" >/dev/null 2>&1 || true
      /bin/sleep 1
    fi

    if /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
      echo "App process still running; terminating process"
      /bin/kill "$APP_PID" >/dev/null 2>&1 || true
      /bin/sleep 1
    fi

    echo "Upgrading $CASK_TOKEN"
    "$BREW_PATH" upgrade --cask "$CASK_TOKEN"

    echo "Reopening $TARGET_APP"
    /usr/bin/open "$TARGET_APP" || /usr/bin/open -a "$APP_NAME"
    /bin/rm -rf "$WORK_DIR"
    """
}
