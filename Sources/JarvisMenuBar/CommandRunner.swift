import Foundation

enum CommandRunnerError: LocalizedError {
    case executableNotFound(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            "Executable not found: \(path)"
        case .launchFailed(let message):
            "Command failed to launch: \(message)"
        }
    }
}

struct CommandRunner {
    var redactsOutput = true

    func run(
        executable: String,
        arguments: [String],
        currentDirectory: String? = nil,
        timeout: TimeInterval = 15
    ) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.runBlocking(
                executable: executable,
                arguments: arguments,
                currentDirectory: currentDirectory,
                timeout: timeout,
                redactsOutput: redactsOutput
            )
        }.value
    }

    private static func runBlocking(
        executable: String,
        arguments: [String],
        currentDirectory: String?,
        timeout: TimeInterval,
        redactsOutput: Bool
    ) throws -> CommandResult {
        let startedAt = Date()
        let expandedExecutable = FilePath.expandingTilde(in: executable)
        guard FileManager.default.isExecutableFile(atPath: expandedExecutable) else {
            throw CommandRunnerError.executableNotFound(expandedExecutable)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: expandedExecutable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: FilePath.expandingTilde(in: currentDirectory))
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let outputQueue = DispatchQueue(label: "jarvis.command-output", attributes: .concurrent)
        var stdoutData = Data()
        var stderrData = Data()
        let outputGroup = DispatchGroup()

        outputGroup.enter()
        outputQueue.async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            outputGroup.leave()
        }

        outputGroup.enter()
        outputQueue.async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            outputGroup.leave()
        }

        do {
            try process.run()
        } catch {
            throw CommandRunnerError.launchFailed(error.localizedDescription)
        }

        let waitGroup = DispatchGroup()
        waitGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            waitGroup.leave()
        }

        let timedOut = waitGroup.wait(timeout: .now() + timeout) == .timedOut
        if timedOut {
            process.terminate()
            _ = waitGroup.wait(timeout: .now() + 2)
            if process.isRunning {
                process.interrupt()
                process.waitUntilExit()
            }
        }

        outputGroup.wait()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let safeStdout = redactsOutput ? Redactor.redactText(stdout) : stdout
        let safeStderr = redactsOutput ? Redactor.redactText(stderr) : stderr

        return CommandResult(
            executable: expandedExecutable,
            arguments: arguments,
            currentDirectory: currentDirectory,
            exitCode: timedOut ? -1 : process.terminationStatus,
            stdout: safeStdout,
            stderr: safeStderr,
            timedOut: timedOut,
            duration: Date().timeIntervalSince(startedAt)
        )
    }
}

enum FilePath {
    static func expandingTilde(in path: String) -> String {
        guard path.hasPrefix("~") else {
            return path
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == "~" {
            return home
        }
        if path.hasPrefix("~/") {
            return home + String(path.dropFirst())
        }
        return path
    }

    static func abbreviatingHome(in path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
