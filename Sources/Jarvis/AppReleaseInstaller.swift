import AppKit
import Foundation

enum AppReleaseInstallerError: LocalizedError {
    case notRunningFromAppBundle
    case helperLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            return "Self-update requires running from the packaged \(AppIdentity.displayName).app bundle."
        case .helperLaunchFailed(let message):
            return "Could not start the update installer: \(message)"
        }
    }
}

struct AppReleaseInstaller {
    static let expectedAppName = "\(AppIdentity.displayName).app"

    func installDownloadedRelease(
        archiveURL: URL,
        bundleURL: URL? = AppReleaseInstaller.currentAppBundleURL(),
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) throws {
        guard let bundleURL else {
            throw AppReleaseInstallerError.notRunningFromAppBundle
        }

        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("\(AppIdentity.executableName)Update-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        let stagedArchiveURL = workDirectory.appendingPathComponent(AppIdentity.releaseAssetName)
        if fileManager.fileExists(atPath: stagedArchiveURL.path) {
            try fileManager.removeItem(at: stagedArchiveURL)
        }
        try fileManager.moveItem(at: archiveURL, to: stagedArchiveURL)

        let helperURL = workDirectory.appendingPathComponent("install_update.sh")
        try Self.helperScript.write(to: helperURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            helperURL.path,
            stagedArchiveURL.path,
            bundleURL.deletingLastPathComponent().path,
            bundleURL.lastPathComponent,
            String(processIdentifier),
            workDirectory.path
        ]

        do {
            try process.run()
        } catch {
            throw AppReleaseInstallerError.helperLaunchFailed(error.localizedDescription)
        }
    }

    static func currentAppBundleURL(bundle: Bundle = .main) -> URL? {
        appBundleURL(containing: bundle.bundleURL)
            ?? bundle.executableURL.flatMap(appBundleURL(containing:))
    }

    static func appBundleURL(containing url: URL) -> URL? {
        var candidate = url.standardizedFileURL
        while candidate.path != "/" {
            if candidate.pathExtension == "app" {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }

    static let helperScript = """
    #!/usr/bin/env bash
    set -euo pipefail

    ZIP_PATH="$1"
    INSTALL_DIR="$2"
    APP_NAME="$3"
    APP_PID="$4"
    WORK_DIR="$5"
    TARGET_APP="$INSTALL_DIR/$APP_NAME"
    UNPACK_DIR="$WORK_DIR/unpack"
    LOG_PATH="$WORK_DIR/install.log"
    TEMP_TARGET="$INSTALL_DIR/.Jarvis.updating.$$.app"

    mkdir -p "$WORK_DIR"
    exec >> "$LOG_PATH" 2>&1

    notify_failure() {
      /usr/bin/osascript -e "display notification \\"Update failed. See $LOG_PATH\\" with title \\"Jarvis\\"" >/dev/null 2>&1 || true
    }
    trap notify_failure ERR

    echo "Waiting for app process $APP_PID to exit"
    for _ in {1..100}; do
      if ! /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
        break
      fi
      /bin/sleep 0.2
    done

    if /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
      echo "App process still running; asking it to quit"
      /usr/bin/osascript -e 'tell application "Jarvis" to quit' >/dev/null 2>&1 || true
      /bin/sleep 1
    fi

    if /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
      echo "App process still running; terminating process"
      /bin/kill "$APP_PID" >/dev/null 2>&1 || true
      /bin/sleep 1
    fi

    echo "Unpacking release archive"
    /bin/rm -rf "$UNPACK_DIR"
    /bin/mkdir -p "$UNPACK_DIR"
    /usr/bin/ditto -x -k "$ZIP_PATH" "$UNPACK_DIR"

    SOURCE_APP="$UNPACK_DIR/$APP_NAME"
    if [[ ! -d "$SOURCE_APP" ]]; then
      SOURCE_APP="$(/usr/bin/find "$UNPACK_DIR" -maxdepth 2 -name '*.app' -type d | /usr/bin/head -n 1)"
    fi

    if [[ -z "${SOURCE_APP:-}" || ! -d "$SOURCE_APP" ]]; then
      echo "Release archive did not contain an app bundle"
      exit 1
    fi

    echo "Installing $SOURCE_APP to $TARGET_APP"
    /bin/rm -rf "$TEMP_TARGET"
    /usr/bin/ditto "$SOURCE_APP" "$TEMP_TARGET"
    /bin/rm -rf "$TARGET_APP"
    /bin/mv "$TEMP_TARGET" "$TARGET_APP"
    /usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true

    echo "Reopening $TARGET_APP"
    /usr/bin/open "$TARGET_APP"
    /bin/rm -rf "$WORK_DIR"
    """
}
