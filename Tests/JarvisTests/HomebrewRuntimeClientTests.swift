import XCTest
@testable import Jarvis

final class HomebrewRuntimeClientTests: XCTestCase {
    func testParsesInstalledFormulaVersion() {
        XCTAssertEqual(
            HomebrewRuntimeClient.version(from: "jarvis 0.1.0\n", token: "jarvis"),
            "0.1.0"
        )
    }

    func testMissingFormulaVersionReturnsNil() {
        XCTAssertNil(HomebrewRuntimeClient.version(from: "other 1.0.0\n", token: "jarvis"))
    }

    func testRuntimeUpdateTrustsSpecificFormulaBeforeUpgrade() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JarvisRuntimeBrewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let log = directory.appendingPathComponent("brew.log")
        let brew = directory.appendingPathComponent("brew")
        let script = """
        #!/usr/bin/env bash
        echo "$@" >> "\(log.path)"
        exit 0
        """
        try script.write(to: brew, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: brew.path)

        let results = try await HomebrewRuntimeClient(brewPath: brew.path).update()

        XCTAssertEqual(results.map(\.arguments), [
            ["trust", "--formula", "roughcoder/infinite-stack/jarvis"],
            ["update"],
            ["upgrade", "jarvis"]
        ])
        let logText = try String(contentsOf: log, encoding: .utf8)
        XCTAssertTrue(logText.contains("help trust"))
        XCTAssertTrue(logText.contains("trust --formula roughcoder/infinite-stack/jarvis"))
    }
}
