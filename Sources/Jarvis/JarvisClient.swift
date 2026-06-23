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

struct JarvisInvocation: Equatable {
    let executable: String
    let arguments: [String]
    let currentDirectory: String?
    let environment: [String: String]
    let mode: RuntimeMode

    enum RuntimeMode: Equatable {
        case checkout
        case installed
    }
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
    static let defaultInstalledWorkdir = "\(NSHomeDirectory())/.jarvis"

    func fleetStatus(includeDocker: Bool) async throws -> FleetStatusResponse {
        var arguments = ["fleet-status", "--json"]
        if !includeDocker {
            arguments.append("--no-docker")
        }

        let result = try await runJarvis(arguments: arguments, timeout: includeDocker ? 30 : 12)
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
        let roles = Self.orderedInstalledRoles(for: configuration.installedRoles)
        guard !roles.isEmpty else {
            throw JarvisClientError.noInstalledRoles
        }

        if runtimeMode() == .installed {
            return try await runJarvis(arguments: serviceSyncArguments(roles: roles), timeout: 600)
        }

        let extras = Self.syncExtras(for: configuration.installedRoles)
        let arguments = extras.reduce(into: ["sync"]) { partial, extra in
            partial.append("--extra")
            partial.append(extra)
        }
        return try await runUV(arguments: arguments, timeout: 300)
    }

    func serviceSyncArguments(roles: [JarvisRole]) -> [String] {
        ["service", "sync"] + roles.map(\.rawValue)
    }

    func installService(role: JarvisRole) async throws -> CommandResult {
        try await runJarvis(arguments: serviceInstallArguments(role: role), timeout: 30)
    }

    func serviceInstallArguments(role: JarvisRole) -> [String] {
        var arguments = ["service", "install", role.rawValue]
        if runtimeMode() == .installed {
            arguments.append(contentsOf: [
                "--jarvis-bin", configuration.jarvisPath,
                "--workdir", Self.defaultInstalledWorkdir
            ])
        }
        return arguments
    }

    func issuePairing(
        deviceID: String,
        identity: String = "",
        brainHost: String = "",
        applyBrainConfig: Bool = false,
        brainBindHost: String = "",
        envFile: String = ""
    ) async throws -> PairingIssue {
        let arguments = pairingArguments(
            deviceID: deviceID,
            identity: identity,
            brainHost: brainHost,
            applyBrainConfig: applyBrainConfig,
            brainBindHost: brainBindHost,
            envFile: envFile
        )
        let result = try await runJarvis(arguments: arguments, timeout: 15)
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

    func pairingArguments(
        deviceID: String,
        identity: String = "",
        brainHost: String = "",
        applyBrainConfig: Bool = false,
        brainBindHost: String = "",
        envFile: String = ""
    ) -> [String] {
        var arguments = ["pair", deviceID, "--json"]
        let trimmedIdentity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedIdentity.isEmpty {
            arguments.append(contentsOf: ["--identity", trimmedIdentity])
        }
        if applyBrainConfig {
            arguments.append("--apply-brain-config")
            let trimmedEnvFile = envFile.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedEnvFile.isEmpty {
                arguments.append(contentsOf: ["--env-file", trimmedEnvFile])
            }
            let trimmedBrainBindHost = brainBindHost.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedBrainBindHost.isEmpty {
                arguments.append(contentsOf: ["--brain-bind-host", trimmedBrainBindHost])
            }
        }
        let trimmedBrainHost = brainHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBrainHost.isEmpty {
            arguments.append(contentsOf: [
                "--mac-config",
                "--pi-installer",
                "--brain-host", trimmedBrainHost
            ])
        }
        return arguments
    }

    func checkBrain(host: String, port: String = "8700") async throws -> CommandResult {
        try await runJarvis(arguments: brainStatusArguments(host: host, port: port), timeout: 12)
    }

    func brainStatusArguments(host: String, port: String = "8700") -> [String] {
        var arguments = ["status", "--json"]
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHost.isEmpty {
            arguments.append(contentsOf: ["--brain-host", trimmedHost])
        }
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPort.isEmpty {
            arguments.append(contentsOf: ["--brain-port", trimmedPort])
        }
        return arguments
    }

    func workerDoctor() async throws -> CommandResult {
        try await runJarvis(arguments: workerDoctorArguments(), timeout: 15)
    }

    func workerDoctorArguments() -> [String] {
        ["worker", "--doctor"]
    }

    func bringupEvidence(
        roles: Set<JarvisRole>,
        brainHost: String = "",
        outputPath: String = ""
    ) async throws -> CommandResult {
        try await runJarvis(
            arguments: bringupArguments(roles: roles, brainHost: brainHost, outputPath: outputPath),
            timeout: 45
        )
    }

    func bringupArguments(
        roles: Set<JarvisRole>,
        brainHost: String = "",
        outputPath: String = ""
    ) -> [String] {
        var arguments = ["bringup", "--json"]
        for role in Self.orderedInstalledRoles(for: roles) {
            arguments.append(contentsOf: ["--role", role.rawValue])
        }
        arguments.append("--hardware")
        let trimmedBrainHost = brainHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBrainHost.isEmpty {
            arguments.append(contentsOf: ["--brain-host", trimmedBrainHost])
        }
        let trimmedOutputPath = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOutputPath.isEmpty {
            arguments.append(contentsOf: ["--output", trimmedOutputPath])
        }
        return arguments
    }

    func bringupSummary(evidencePath: String, outputPath: String = "") async throws -> CommandResult {
        try await runJarvis(
            arguments: bringupSummaryArguments(evidencePath: evidencePath, outputPath: outputPath),
            timeout: 30
        )
    }

    func bringupSummaryArguments(evidencePath: String, outputPath: String = "") -> [String] {
        var arguments = [
            "bringup-summary",
            evidencePath.trimmingCharacters(in: .whitespacesAndNewlines),
            "--json",
            "--expect-role", "brain",
            "--expect-role", "worker",
            "--expect-role", "intercom",
            "--expect-current-release",
            "--min-files", "4"
        ]
        let trimmedOutputPath = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOutputPath.isEmpty {
            arguments.append(contentsOf: ["--output", trimmedOutputPath])
        }
        return arguments
    }

    func runUV(arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        try await runner.run(
            executable: configuration.uvPath,
            arguments: arguments,
            currentDirectory: configuration.jarvisRepoPath,
            environment: [:],
            timeout: timeout
        )
    }

    func runJarvis(arguments: [String], timeout: TimeInterval) async throws -> CommandResult {
        let invocation = jarvisInvocation(arguments: arguments)
        try prepareForInvocation(invocation)
        return try await runner.run(
            executable: invocation.executable,
            arguments: invocation.arguments,
            currentDirectory: invocation.currentDirectory,
            environment: invocation.environment,
            timeout: timeout
        )
    }

    func jarvisInvocation(arguments: [String]) -> JarvisInvocation {
        if runtimeMode() == .checkout {
            return JarvisInvocation(
                executable: configuration.uvPath,
                arguments: ["run", "jarvis"] + arguments,
                currentDirectory: configuration.jarvisRepoPath,
                environment: [:],
                mode: .checkout
            )
        }

        return JarvisInvocation(
            executable: configuration.jarvisPath,
            arguments: arguments,
            currentDirectory: Self.defaultInstalledWorkdir,
            environment: ["JARVIS_ENV_FILE": "\(Self.defaultInstalledWorkdir)/.env"],
            mode: .installed
        )
    }

    func prepareForInvocation(_ invocation: JarvisInvocation) throws {
        guard invocation.mode == .installed,
              let currentDirectory = invocation.currentDirectory
        else {
            return
        }

        let expandedDirectory = FilePath.expandingTilde(in: currentDirectory)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: expandedDirectory, isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func runtimeMode() -> JarvisInvocation.RuntimeMode {
        let repoPath = FilePath.expandingTilde(in: configuration.jarvisRepoPath)
        let markers = [
            "\(repoPath)/pyproject.toml",
            "\(repoPath)/src/jarvis/cli.py"
        ]
        if markers.allSatisfy({ FileManager.default.fileExists(atPath: $0) }),
           FileManager.default.isExecutableFile(atPath: FilePath.expandingTilde(in: configuration.uvPath)) {
            return .checkout
        }
        return .installed
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
        var seen = Set<String>()
        var extras = [String]()

        for role in orderedInstalledRoles(for: roles) {
            for extra in extrasForRole(role) where !seen.contains(extra) {
                seen.insert(extra)
                extras.append(extra)
            }
        }

        return extras
    }

    static func orderedInstalledRoles(for roles: Set<JarvisRole>) -> [JarvisRole] {
        [.brain, .worker, .intercom].filter { roles.contains($0) }
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
