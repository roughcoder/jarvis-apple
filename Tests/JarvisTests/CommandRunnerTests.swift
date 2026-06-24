import XCTest
@testable import Jarvis

final class CommandRunnerTests: XCTestCase {
    func testStandardInputCannotBlockTimeoutHandling() async throws {
        let input = String(repeating: "x", count: 2_000_000)
        let startedAt = Date()

        let result = try await CommandRunner(redactsOutput: false).run(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 5"],
            standardInput: input,
            timeout: 0.25
        )

        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 3)
    }
}
