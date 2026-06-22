import Foundation

struct HomebrewRuntimeClient {
    private let runner: CommandRunner
    private let brewPath: String?

    init(
        runner: CommandRunner = CommandRunner(redactsOutput: false),
        brewPath: String? = HomebrewReleaseClient.defaultBrewPath()
    ) {
        self.runner = runner
        self.brewPath = brewPath
    }

    func installedVersion(token: String = AppIdentity.homebrewFormulaToken) async throws -> String? {
        guard let brewPath else {
            return nil
        }

        let result = try await runner.run(
            executable: brewPath,
            arguments: ["list", "--formula", "--versions", token],
            timeout: 20
        )
        guard result.succeeded else {
            return nil
        }

        return Self.version(from: result.stdout, token: token)
    }

    func update(token: String = AppIdentity.homebrewFormulaToken) async throws -> [CommandResult] {
        guard let brewPath else {
            return []
        }

        let update = try await runner.run(
            executable: brewPath,
            arguments: ["update"],
            timeout: 90
        )
        let upgrade = try await runner.run(
            executable: brewPath,
            arguments: ["upgrade", token],
            timeout: 300
        )
        return [update, upgrade]
    }

    static func version(from output: String, token: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { $0.hasPrefix(token) }?
            .split(separator: " ")
            .dropFirst()
            .first
            .map(String.init)
    }
}
