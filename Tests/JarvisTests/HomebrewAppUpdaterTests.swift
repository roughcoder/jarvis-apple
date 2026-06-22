import XCTest
@testable import Jarvis

final class HomebrewAppUpdaterTests: XCTestCase {
    func testHelperScriptRunsBrewUpgradeAndReopensApp() {
        XCTAssertTrue(HomebrewAppUpdater.helperScript.contains(#""$BREW_PATH" update"#))
        XCTAssertTrue(HomebrewAppUpdater.helperScript.contains(#""$BREW_PATH" upgrade --cask "$CASK_TOKEN""#))
        XCTAssertTrue(HomebrewAppUpdater.helperScript.contains(#"/usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP""#))
        XCTAssertTrue(HomebrewAppUpdater.helperScript.contains(#"/usr/bin/open "$TARGET_APP""#))
        XCTAssertFalse(HomebrewAppUpdater.helperScript.contains("GH_PATH"))
        XCTAssertFalse(HomebrewAppUpdater.helperScript.contains("HOMEBREW_GITHUB_API_TOKEN"))
    }

    func testHelperScriptIsValidBashSyntax() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JarvisBrewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let script = directory.appendingPathComponent("brew_update.sh")
        try HomebrewAppUpdater.helperScript.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-n", script.path]
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
    }
}
