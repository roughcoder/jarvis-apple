import Darwin
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
    private static let ignoreBrokenPipeSignal: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()

    func run(
        executable: String,
        arguments: [String],
        currentDirectory: String? = nil,
        environment: [String: String] = [:],
        standardInput: String? = nil,
        timeout: TimeInterval = 15
    ) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.runBlocking(
                executable: executable,
                arguments: arguments,
                currentDirectory: currentDirectory,
                environment: environment,
                standardInput: standardInput,
                timeout: timeout,
                redactsOutput: redactsOutput
            )
        }.value
    }

    private static func runBlocking(
        executable: String,
        arguments: [String],
        currentDirectory: String?,
        environment: [String: String],
        standardInput: String?,
        timeout: TimeInterval,
        redactsOutput: Bool
    ) throws -> CommandResult {
        _ = ignoreBrokenPipeSignal
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
        if !environment.isEmpty {
            var merged = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                merged[key] = FilePath.expandingTilde(in: value)
            }
            process.environment = merged
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let stdinPipe = Pipe()
        if standardInput != nil {
            process.standardInput = stdinPipe
        }

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

        let stdinGroup = DispatchGroup()
        if let standardInput {
            stdinGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                writeStandardInput(standardInput, to: stdinPipe.fileHandleForWriting)
                stdinGroup.leave()
            }
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

        _ = stdinGroup.wait(timeout: .now() + 2)
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

    private static func writeStandardInput(_ standardInput: String, to handle: FileHandle) {
        let data = Data(standardInput.utf8)
        let fileDescriptor = handle.fileDescriptor
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }
            var offset = 0
            while offset < rawBuffer.count {
                let remaining = rawBuffer.count - offset
                let chunkSize = min(remaining, 16 * 1024)
                let written = Darwin.write(fileDescriptor, baseAddress.advanced(by: offset), chunkSize)
                if written > 0 {
                    offset += written
                } else if written == -1 && errno == EINTR {
                    continue
                } else {
                    break
                }
            }
        }
        Darwin.close(fileDescriptor)
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
