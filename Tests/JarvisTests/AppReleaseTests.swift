import XCTest
@testable import Jarvis

final class AppReleaseTests: XCTestCase {
    func testSemanticVersionComparisonHandlesVPrefix() {
        XCTAssertTrue(AppVersion.isRelease("v0.2.0", newerThan: "0.1.9"))
        XCTAssertFalse(AppVersion.isRelease("v0.1.0", newerThan: "0.1.0"))
        XCTAssertFalse(AppVersion.isRelease("0.1.0-beta", newerThan: "0.1.0"))
    }

    func testNormalizesGitHubRepositoryInputs() throws {
        XCTAssertEqual(
            try GitHubReleaseClient.normalizedRepository("git@github.com:roughcoder/jarvis-apple.git"),
            "roughcoder/jarvis-apple"
        )
        XCTAssertEqual(
            try GitHubReleaseClient.normalizedRepository("https://github.com/roughcoder/jarvis-apple.git"),
            "roughcoder/jarvis-apple"
        )
        XCTAssertEqual(
            try GitHubReleaseClient.normalizedRepository("roughcoder/jarvis-apple"),
            "roughcoder/jarvis-apple"
        )
    }
}
