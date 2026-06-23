import Foundation

enum HomebrewReleaseClientError: LocalizedError {
    case commandFailed(CommandResult)
    case invalidOutput(String)
    case tapNotTrusted

    var errorDescription: String? {
        switch self {
        case .commandFailed(let result):
            let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? "Homebrew command failed." : output
        case .invalidOutput(let output):
            return "Could not parse Homebrew output: \(output)"
        case .tapNotTrusted:
            return "Homebrew tap entry is not trusted. Run `brew trust --cask \(AppIdentity.homebrewTap)/\(AppIdentity.homebrewCaskToken)`, then check again."
        }
    }
}

struct HomebrewCaskStatus: Equatable {
    let token: String
    let installedVersion: String
    let latestVersion: String?
    let isOutdated: Bool

    var displayLatestVersion: String {
        latestVersion ?? installedVersion
    }
}

struct HomebrewReleaseClient {
    private let runner: CommandRunner
    private let brewPath: String?

    init(
        runner: CommandRunner = CommandRunner(redactsOutput: false),
        brewPath: String? = Self.defaultBrewPath()
    ) {
        self.runner = runner
        self.brewPath = brewPath
    }

    func caskStatus(
        token: String = AppIdentity.homebrewCaskToken,
        updateHomebrew: Bool = false
    ) async throws -> HomebrewCaskStatus? {
        guard let brewPath else {
            return nil
        }

        let list = try await runner.run(
            executable: brewPath,
            arguments: ["list", "--cask", "--versions", token],
            timeout: 20
        )
        if !list.succeeded {
            if Self.outputRequiresTrust(list.combinedOutput) {
                throw HomebrewReleaseClientError.tapNotTrusted
            }
            return nil
        }

        let installedVersion = try Self.installedVersion(from: list.stdout, token: token)

        if updateHomebrew {
            let update = try await runner.run(
                executable: brewPath,
                arguments: ["update"],
                timeout: 90
            )
            if !update.succeeded {
                if Self.outputRequiresTrust(update.combinedOutput) {
                    throw HomebrewReleaseClientError.tapNotTrusted
                }
                throw HomebrewReleaseClientError.commandFailed(update)
            }
        }

        let outdated = try await runner.run(
            executable: brewPath,
            arguments: ["outdated", "--cask", "--json=v2", token],
            timeout: 45
        )
        if !outdated.succeeded {
            if Self.outputRequiresTrust(outdated.combinedOutput) {
                throw HomebrewReleaseClientError.tapNotTrusted
            }
            throw HomebrewReleaseClientError.commandFailed(outdated)
        }

        return try Self.status(
            fromOutdatedJSON: Data(outdated.stdout.utf8),
            token: token,
            installedVersion: installedVersion
        )
    }

    static func defaultBrewPath(fileManager: FileManager = .default) -> String? {
        [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ].first { fileManager.isExecutableFile(atPath: $0) }
    }

    static func installedVersion(from output: String, token: String) throws -> String {
        guard let line = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { $0.hasPrefix(token) }) else {
            throw HomebrewReleaseClientError.invalidOutput(output)
        }

        let parts = line.split(separator: " ").map(String.init)
        guard parts.count >= 2 else {
            throw HomebrewReleaseClientError.invalidOutput(output)
        }
        return parts[1]
    }

    static func status(
        fromOutdatedJSON data: Data,
        token: String,
        installedVersion: String
    ) throws -> HomebrewCaskStatus {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw HomebrewReleaseClientError.invalidOutput(String(data: data, encoding: .utf8) ?? "")
        }

        let casks = root["casks"] as? [[String: Any]] ?? []
        guard let cask = casks.first(where: { ($0["name"] as? String) == token }) else {
            return HomebrewCaskStatus(
                token: token,
                installedVersion: installedVersion,
                latestVersion: installedVersion,
                isOutdated: false
            )
        }

        let latestVersion = (cask["current_version"] as? String)
            ?? (cask["current_versions"] as? [String])?.first
            ?? (cask["version"] as? String)
        let installed = (cask["installed_versions"] as? [String])?.first ?? installedVersion
        let latest = (cask["current_version"] as? String)
            ?? (cask["current_versions"] as? [String])?.first
            ?? (cask["version"] as? String)
        let isOutdated = Self.isOutdated(cask, installedVersion: installed, latestVersion: latest)

        return HomebrewCaskStatus(
            token: token,
            installedVersion: installed,
            latestVersion: latest,
            isOutdated: isOutdated
        )
    }

    private static func isOutdated(
        _ cask: [String: Any],
        installedVersion: String,
        latestVersion: String?
    ) -> Bool {
        if let explicitOutdated = cask["outdated"] as? Bool {
            return explicitOutdated
        }

        guard let latestVersion else {
            return false
        }

        return AppVersion.isRelease(latestVersion, newerThan: installedVersion)
    }

    static func outputRequiresTrust(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("untrusted tap")
            || output.localizedCaseInsensitiveContains("brew trust")
    }
}
