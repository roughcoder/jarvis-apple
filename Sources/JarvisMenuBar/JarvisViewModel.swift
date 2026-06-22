import AppKit
import Foundation

@MainActor
final class JarvisViewModel: ObservableObject {
    @Published var fleetStatus = FleetStatus.placeholder
    @Published var isRefreshing = false
    @Published var activeOperation: String?
    @Published var lastCommandOutput = ""
    @Published var lastError: String?
    @Published var latestAppRelease: AppRelease?
    @Published var appReleaseStatus = "Not checked"
    @Published var isCheckingAppRelease = false
    @Published var isDownloadingAppRelease = false

    private let settings: AppSettings
    private var pollIteration = 0
    private var didCheckAppRelease = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    var isBusy: Bool {
        activeOperation != nil
    }

    var currentAppVersion: String {
        AppVersion.current
    }

    var hasInstallableAppRelease: Bool {
        latestAppRelease?.assetURL != nil
    }

    func startPolling() async {
        await refresh(includeDocker: true)
        if !didCheckAppRelease {
            didCheckAppRelease = true
            await checkForAppRelease(silent: true)
        }

        while !Task.isCancelled {
            let interval = UInt64(max(settings.pollInterval, 2) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
            if Task.isCancelled {
                return
            }

            pollIteration += 1
            let includeDocker = settings.dockerChecksEnabled && pollIteration % fullRefreshModulo == 0
            await refresh(includeDocker: includeDocker)
        }
    }

    func refresh(includeDocker: Bool? = nil) async {
        if isRefreshing {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let shouldIncludeDocker = includeDocker ?? settings.dockerChecksEnabled
        do {
            let response = try await JarvisClient(configuration: settings.configuration)
                .fleetStatus(includeDocker: shouldIncludeDocker)
            fleetStatus = response.status
            lastError = nil
        } catch {
            lastError = readableError(error)
        }
    }

    func performLaunchd(_ action: LaunchdAction, role: JarvisRole) async {
        await perform("Running \(role.title) \(action.title)") {
            try await JarvisClient(configuration: settings.configuration).launchd(action, role: role)
        }
        await refresh(includeDocker: true)
    }

    func performDocker(_ action: DockerAction) async {
        await perform("Running Docker \(action.title)") {
            try await JarvisClient(configuration: settings.configuration).docker(action)
        }
        await refresh(includeDocker: true)
    }

    func updateInstalledRoles() async {
        guard !settings.installedRoles.isEmpty else {
            lastError = JarvisClientError.noInstalledRoles.localizedDescription
            return
        }

        let client = JarvisClient(configuration: settings.configuration)
        activeOperation = "Preparing update"
        lastError = nil
        lastCommandOutput = ""

        do {
            append("Checking Jarvis status")
            let statusResponse = try await client.fleetStatus(includeDocker: true)
            fleetStatus = statusResponse.status
            append(statusResponse.command, label: "fleet-status")

            if statusResponse.status.git.dirty == true {
                throw JarvisClientError.dirtyWorkingTree(statusResponse.status.git.detail)
            }

            if statusResponse.status.git.dirty == nil {
                activeOperation = "Checking working tree"
                let porcelain = try await client.gitStatusPorcelain()
                append(porcelain, label: "git status --porcelain")
                if !porcelain.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw JarvisClientError.dirtyWorkingTree(porcelain.stdout)
                }
            }

            activeOperation = "Pulling latest Jarvis"
            let pull = try await client.gitPullFastForwardOnly()
            append(pull, label: "git pull --ff-only")
            try requireSuccess(pull)

            activeOperation = "Syncing role dependencies"
            append("Sync extras: \(JarvisClient.syncExtras(for: settings.installedRoles).joined(separator: ", "))")
            let sync = try await client.uvSyncForInstalledRoles()
            append(sync, label: "uv sync")
            try requireSuccess(sync)

            for role in JarvisRole.allCases where settings.installedRoles.contains(role) {
                activeOperation = "Restarting \(role.title)"
                let restart = try await client.launchd(.restart, role: role)
                append(restart, label: "launchctl kickstart \(role.title)")
                try requireSuccess(restart)
            }

            activeOperation = "Refreshing status"
            let refreshed = try await client.fleetStatus(includeDocker: true)
            fleetStatus = refreshed.status
            append(refreshed.command, label: "fleet-status")
            activeOperation = nil
            lastError = nil
        } catch {
            activeOperation = nil
            lastError = readableError(error)
            append("ERROR: \(readableError(error))")
        }
    }

    func openJarvisRepo() {
        openPath(settings.jarvisRepoPath)
    }

    func openLogsFolder() {
        openPath(settings.logsPath)
    }

    func openLog(for role: JarvisRole) {
        openPath("\(settings.logsPath)/\(role.rawValue).err.log")
    }

    func copyStatusJSON() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fleetStatus.rawJSON, forType: .string)
        lastCommandOutput = "Copied redacted fleet-status JSON to the clipboard."
    }

    func checkForAppRelease(silent: Bool = false) async {
        let repository = settings.appReleaseRepository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repository.isEmpty else {
            appReleaseStatus = "No GitHub release repo configured"
            return
        }

        isCheckingAppRelease = true
        if !silent {
            appReleaseStatus = "Checking GitHub Releases"
        }
        defer { isCheckingAppRelease = false }

        do {
            let release = try await GitHubReleaseClient().latestRelease(repository: repository)
            latestAppRelease = release
            if AppVersion.isRelease(release.tagName, newerThan: currentAppVersion) {
                appReleaseStatus = "\(release.tagName) available"
            } else {
                appReleaseStatus = "Up to date (\(currentAppVersion))"
            }
        } catch {
            latestAppRelease = nil
            appReleaseStatus = readableError(error)
            if !silent {
                lastError = readableError(error)
            }
        }
    }

    func downloadLatestAppRelease() async {
        guard let release = latestAppRelease else {
            await checkForAppRelease()
            guard latestAppRelease != nil else {
                return
            }
            await downloadLatestAppRelease()
            return
        }

        guard let assetURL = release.assetURL else {
            openLatestAppRelease()
            return
        }

        isDownloadingAppRelease = true
        activeOperation = "Downloading \(release.assetName ?? release.tagName)"
        lastError = nil
        defer {
            isDownloadingAppRelease = false
            activeOperation = nil
        }

        do {
            let (temporaryURL, _) = try await URLSession.shared.download(from: assetURL)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
                .first ?? FileManager.default.homeDirectoryForCurrentUser
            let targetName = release.assetName ?? "JarvisMenuBar-\(release.tagName)-macos.zip"
            let targetURL = downloads.appendingPathComponent(targetName)

            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
            appReleaseStatus = "Downloaded \(targetName)"
            lastCommandOutput = "Downloaded \(targetName) to \(targetURL.path). Use the release install script or unzip the app bundle into /Applications."
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
        } catch {
            lastError = readableError(error)
            appReleaseStatus = readableError(error)
        }
    }

    func openLatestAppRelease() {
        if let release = latestAppRelease {
            NSWorkspace.shared.open(release.htmlURL)
        } else if let repository = try? GitHubReleaseClient.normalizedRepository(settings.appReleaseRepository),
                  let url = URL(string: "https://github.com/\(repository)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    private func perform(_ title: String, operation: () async throws -> CommandResult) async {
        guard activeOperation == nil else {
            return
        }

        activeOperation = title
        lastError = nil
        do {
            let result = try await operation()
            append(result, label: title)
            try requireSuccess(result)
            activeOperation = nil
        } catch {
            activeOperation = nil
            lastError = readableError(error)
            append("ERROR: \(readableError(error))")
        }
    }

    private func requireSuccess(_ result: CommandResult) throws {
        guard result.succeeded else {
            throw JarvisClientError.commandFailed(result)
        }
    }

    private func append(_ result: CommandResult, label: String) {
        let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = output.isEmpty ? "(no output)" : output
        append(
            """
            $ \(result.commandLine)
            [\(label)] exit \(result.exitCode), \(String(format: "%.1fs", result.duration))
            \(body)
            """
        )
    }

    private func append(_ message: String) {
        if lastCommandOutput.isEmpty {
            lastCommandOutput = message
        } else {
            lastCommandOutput += "\n\n\(message)"
        }
    }

    private func openPath(_ path: String) {
        let expanded = FilePath.expandingTilde(in: path)
        NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
    }

    private func readableError(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private var fullRefreshModulo: Int {
        max(1, Int(round(30 / max(settings.pollInterval, 1))))
    }
}

private extension LaunchdAction {
    var title: String {
        switch self {
        case .start: "start"
        case .restart: "restart"
        case .stop: "stop"
        case .printStatus: "status"
        }
    }
}

private extension DockerAction {
    var title: String {
        switch self {
        case .start: "start"
        case .restart: "restart"
        case .stop: "stop"
        case .ps: "ps"
        }
    }
}
