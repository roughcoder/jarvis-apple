import XCTest
@testable import Jarvis

final class HomebrewReleaseClientTests: XCTestCase {
    func testParsesInstalledCaskVersion() throws {
        XCTAssertEqual(
            try HomebrewReleaseClient.installedVersion(from: "jarvis-app 0.2.2\n", token: "jarvis-app"),
            "0.2.2"
        )
    }

    func testParsesOutdatedCaskJSON() throws {
        let json = """
        {
          "formulae": [],
          "casks": [
            {
              "name": "jarvis-app",
              "installed_versions": ["0.2.2"],
              "current_version": "0.2.3"
            }
          ]
        }
        """

        let status = try HomebrewReleaseClient.status(
            fromOutdatedJSON: Data(json.utf8),
            token: "jarvis-app",
            installedVersion: "0.2.2"
        )

        XCTAssertEqual(status.installedVersion, "0.2.2")
        XCTAssertEqual(status.latestVersion, "0.2.3")
        XCTAssertTrue(status.isOutdated)
    }

    func testEmptyOutdatedJSONMeansUpToDate() throws {
        let status = try HomebrewReleaseClient.status(
            fromOutdatedJSON: Data(#"{"formulae":[],"casks":[]}"#.utf8),
            token: "jarvis-app",
            installedVersion: "0.2.2"
        )

        XCTAssertEqual(status.installedVersion, "0.2.2")
        XCTAssertEqual(status.latestVersion, "0.2.2")
        XCTAssertFalse(status.isOutdated)
    }

    func testDetectsUntrustedTapOutput() {
        XCTAssertTrue(HomebrewReleaseClient.outputRequiresTrust("Refusing to load cask from untrusted tap. Run `brew trust roughcoder/infinite-stack`."))
        XCTAssertFalse(HomebrewReleaseClient.outputRequiresTrust("jarvis-app 0.2.2"))
    }

    func testTapTrustErrorUsesSpecificCaskTrust() {
        XCTAssertEqual(
            HomebrewReleaseClientError.tapNotTrusted.localizedDescription,
            "Homebrew tap entry is not trusted. Run `brew trust --cask roughcoder/infinite-stack/jarvis-app`, then check again."
        )
    }
}
