import XCTest
@testable import Jarvis

final class FleetStatusParserTests: XCTestCase {
    func testParsesHealthyFleetStatusAndRedactsSecrets() throws {
        let json = """
        {
          "version": "1.2.3",
          "device_id": "macbook",
          "platform": "macOS",
          "services": {
            "brain": { "loaded": true },
            "intercom": { "loaded": true },
            "worker": { "loaded": true }
          },
          "brain": { "reachable": true, "paired": true, "pairing_token": "secret-token" },
          "intercom": { "paired": true },
          "worker": { "reachable": true, "jobs": { "running": 2, "statuses": ["ok", "done"] } },
          "docker": { "all_running": true },
          "git": { "dirty": false, "branch": "main", "revision": "abc123" },
          "pairing": { "identity": "operator", "scope": "local", "capabilities": ["jobs", "traces"] }
        }
        """

        let status = try FleetStatusParser.parse(data: Data(json.utf8))

        XCTAssertEqual(status.version, "1.2.3")
        XCTAssertEqual(status.deviceID, "macbook")
        XCTAssertEqual(status.overall, .green)
        XCTAssertEqual(status.roles.first { $0.role == .brain }?.level, .green)
        XCTAssertEqual(status.roles.first { $0.role == .worker }?.level, .green)
        XCTAssertEqual(status.worker.runningJobs, 2)
        XCTAssertEqual(status.pairing.capabilityCount, 2)
        XCTAssertFalse(status.rawJSON.contains("secret-token"))
        XCTAssertTrue(status.rawJSON.contains("<redacted>"))
    }

    func testMissingFieldsBecomeUnknown() throws {
        let status = try FleetStatusParser.parse(data: Data(#"{"device_id":"laptop"}"#.utf8))

        XCTAssertEqual(status.version, "unknown")
        XCTAssertEqual(status.deviceID, "laptop")
        XCTAssertEqual(status.docker.level, .unknown)
        XCTAssertEqual(status.git.level, .unknown)
        XCTAssertTrue(status.roles.allSatisfy { $0.level == .unknown })
    }

    func testIntercomLoadedButUnpairedIsAmber() throws {
        let json = """
        {
          "services": { "intercom": { "loaded": true } },
          "intercom": { "paired": false },
          "docker": { "available": false },
          "git": { "dirty": false }
        }
        """

        let status = try FleetStatusParser.parse(data: Data(json.utf8))

        XCTAssertEqual(status.roles.first { $0.role == .intercom }?.level, .amber)
    }
}
