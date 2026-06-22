import Darwin
import Foundation

enum JarvisClientError: LocalizedError {
    case commandFailed(CommandResult)
    case dirtyWorkingTree(String)
    case noInstalledRoles
    case invalidStatusJSON(String)
    case invalidPairingJSON(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let result):
            let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty
                ? "\(result.commandLine) failed with exit code \(result.exitCode)."
                : output
        case .dirtyWorkingTree(let detail):
            return "Update blocked because the Jarvis working tree is dirty.\n\(detail)"
        case .noInstalledRoles:
            return "No installed roles are selected in Settings."
        case .invalidStatusJSON(let output):
            return "fleet-status did not return valid JSON.\n\(output)"
        case .invalidPairingJSON(let output):
            return "jarvis pair did not return valid JSON.\n\(output)"
        }
    }
}

struct FleetStatusResponse {
    let status: FleetStatus
    let command: CommandResult
}

enum LaunchdAction {
    case start
    case restart
    case stop
    case printStatus
}

enum DockerAction {
    case start
    case restart
    case stop
    case ps
}

struct JarvisClient {
    let configuration: JarvisConfiguration
    var runner = CommandRunner()

    func fleetStatus(includeDocker: Bool) async throws -> FleetStatusResponse {
        var arguments = ["run", "jarvis", "fleet-status", "--json"]
        if !includeDocker {
            arguments.append("--no-docker")
        }

        let result = try await runUV(arguments: arguments, timeout: includeDocker ? 30 : 12)
        guard result.succeeded else {
            throw JarvisClientError.commandFailed(result)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw JarvisClientError.invalidStatusJSON(result.stdout)
        }

        do {
            return FleetStatusResponse(status: try FleetStatusParser.parse(data: data), command: result)
        } catch {
            throw JarvisClientError.invalidStatusJSON(result.stdout)
        }
    }

    func launchd(_ action: LaunchdAction, role: JarvisRole) async throws -> CommandResult {
        let uid = getuid()
        let domain = "gui/\(uid)"
        let service = "\(domain)/\(role.launchdLabel)"
        let plistPath = FilePath.expandingTilde(in: role.launchAgentPath)

        let arguments: [String]
        switch action {
        case .start:
            arguments = ["bootstrap", domain, plistPath]
        case .restart:
            arguments = ["kickstart", "-k", service]
        case .stop:
            arguments = ["bootout", domain, plistPath]
        case .printStatus:
            arguments = ["print", service]
        }

        return try await runSystem(executable: "/bin/launchctl", arguments: arguments, timeout: 20)
    }

    func docker(_ action: DockerAction) async throws -> CommandResult {
        let arguments: [String]
        switch action {
        case .start:
            arguments = ["compose", "up", "-d"]
        case .restart:
            arguments = ["compose", "restart"]
        case .stop:
            arguments = ["compose", "stop"]
        case .ps:
            arguments = ["compose", "ps"]
        }

        return try await runSystem(
            executable: "/usr/local/bin/docker",
            fallbackExecutables: ["/opt/homebrew/bin/docker", "/Applications/Docker.app/Contents/Resources/bin/docker"],
            arguments: arguments,
            currentDirectory: configuration.jarvisRepoPath,
            timeout: 45
        )
    }

    func gitPullFastForwardOnly() async throws -> CommandResult {
        try await runSystem(
            executable: "/usr/bin/git",
            arguments: ["pull", "--ff-only"],
            currentDirectory: configuration.jarvisRepoPath,
            timeout: 120
        )
    }

    func gitStatusPorcelain() async throws -> CommandResult {
        try await runSystem(
            executable: "/usr/bin/git",
            arguments: ["status", "--porcelain=v1"],
            currentDirectory: configuration.jarvisRepoPath,
            timeout: 15
        )
    }

    func uvSyncForInstalledRoles() async throws -> CommandResult {
        let extras = Self.syncExtras(for: configuration.installedRoles)
        guard !extras.isEmpty else {
            throw JarvisClientError.noInstalledRoles
        }

        let arguments = extras.reduce(into: ["sync"]) { partial, extra in
            partial.append("--extra")
            partial.append(extra)
        }
        return try await runUV(arguments: arguments, timeout: 300)
    }

    func installService(role: JarvisRole) async throws -> CommandResult {
        try await runUV(
            arguments: ["run", "jarvis", "service", "install", role.rawValue],
            timeout: 30
        )
    }

    func issuePairing(deviceID: String, identity: String = "") async throws -> PairingIssue {
        var arguments = ["run", "jarvis", "pair", deviceID, "--json"]
        let trimmedIdentity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedIdentity.isEmpty {
            arguments.append(contentsOf: ["--identity", trimmedIdentity])
        }

        let result = try await runUV(arguments: arguments, timeout: 15)
        guard result.succeeded else {
            throw JarvisClientError.commandFailed(result)
        }
        guard let data = result.stdout.data(using: .utf8) else {
            throw JarvisClientError.invalidPairingJSON(result.stdout)
        }

        do {
            return try PairingIssueParser.parse(data: data)
        } catch {
            throw JarvisClientError.invalidPairingJSON(result.stdout)
        }
    }

    func runUV(arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        try await runner.run(
            executable: configuration.uvPath,
            arguments: arguments,
            currentDirectory: configuration.jarvisRepoPath,
            timeout: timeout
        )
    }

    private func runSystem(
        executable: String,
        fallbackExecutables: [String] = [],
        arguments: [String],
        currentDirectory: String? = nil,
        timeout: TimeInterval
    ) async throws -> CommandResult {
        let candidates = [executable] + fallbackExecutables
        let executablePath = candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? executable
        return try await runner.run(
            executable: executablePath,
            arguments: arguments,
            currentDirectory: currentDirectory,
            timeout: timeout
        )
    }

    static func syncExtras(for roles: Set<JarvisRole>) -> [String] {
        let orderedRoles: [JarvisRole] = [.brain, .worker, .intercom]
        var seen = Set<String>()
        var extras = [String]()

        for role in orderedRoles where roles.contains(role) {
            for extra in extrasForRole(role) where !seen.contains(extra) {
                seen.insert(extra)
                extras.append(extra)
            }
        }

        return extras
    }

    private static func extrasForRole(_ role: JarvisRole) -> [String] {
        switch role {
        case .brain:
            ["gateway", "tts", "stt", "vad", "wake", "memory", "mcp"]
        case .worker:
            ["worker", "browser"]
        case .intercom:
            ["stt", "vad", "wake"]
        }
    }
}
