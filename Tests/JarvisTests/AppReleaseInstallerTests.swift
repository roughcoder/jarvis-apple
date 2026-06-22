import XCTest
@testable import Jarvis

final class AppReleaseInstallerTests: XCTestCase {
    func testFindsContainingAppBundle() {
        let bundle = URL(fileURLWithPath: "/Applications/Jarvis.app/Contents/MacOS/Jarvis")

        XCTAssertEqual(
            AppReleaseInstaller.appBundleURL(containing: bundle)?.path,
            "/Applications/Jarvis.app"
        )
    }

    func testReturnsNilWhenNoAppBundleContainsPath() {
        let executable = URL(fileURLWithPath: "/tmp/Jarvis")

        XCTAssertNil(AppReleaseInstaller.appBundleURL(containing: executable))
    }

    func testHelperScriptReopensInstalledApp() {
        XCTAssertTrue(AppReleaseInstaller.helperScript.contains(#"/usr/bin/open "$TARGET_APP""#))
        XCTAssertTrue(AppReleaseInstaller.helperScript.contains("Jarvis"))
        XCTAssertFalse(AppReleaseInstaller.helperScript.contains("GITHUB_TOKEN"))
    }

    func testHelperScriptIsValidBashSyntax() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JarvisTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let script = directory.appendingPathComponent("install_update.sh")
        try AppReleaseInstaller.helperScript.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-n", script.path]
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
    }
}
