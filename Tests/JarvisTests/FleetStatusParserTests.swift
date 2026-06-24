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
            "worker": { "loaded": true },
            "whatsapp": { "loaded": true }
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
        XCTAssertEqual(status.roles.first { $0.role == .brain }?.loaded, true)
        XCTAssertEqual(status.roles.first { $0.role == .worker }?.level, .green)
        XCTAssertEqual(status.roles.first { $0.role == .whatsapp }?.level, .green)
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

    func testDockerWithoutComposeProjectIsNonBlocking() throws {
        let json = """
        {
          "services": {
            "brain": { "loaded": true },
            "intercom": { "loaded": true },
            "worker": { "loaded": true }
          },
          "brain": { "reachable": true, "auth_configured": true },
          "intercom": { "paired": true },
          "worker": { "reachable": true },
          "docker": {
            "available": false,
            "configured": false,
            "status": "not_configured",
            "detail": "No local Docker compose project found.",
            "services": []
          },
          "git": { "dirty": false }
        }
        """

        let status = try FleetStatusParser.parse(data: Data(json.utf8))

        XCTAssertEqual(status.docker.level, .green)
        XCTAssertEqual(status.docker.detail, "No local Docker compose project found.")
        XCTAssertEqual(status.overall, .green)
    }

    func testFreshHomebrewInstallHealthIsNonBlocking() throws {
        let json = """
        {
          "version": "0.1.21",
          "device_id": "local-mac",
          "brain": {
            "auth_configured": false,
            "bind": "localhost:8700",
            "devices": []
          },
          "docker": {
            "available": false,
            "configured": false,
            "detail": "No local Docker compose project found.",
            "services": [],
            "status": "not_configured"
          },
          "git": { "available": false },
          "intercom": {
            "brain_url": "ws://localhost:8700",
            "device_id": "local-mac",
            "pairing": {
              "capabilities": [],
              "identity": "house",
              "paired": true,
              "reachable": true,
              "scope": "house"
            }
          },
          "services": {
            "brain": { "available": true, "label": "com.jarvis.brain", "loaded": true, "pid": 76189, "state": "active" },
            "intercom": { "available": true, "label": "com.jarvis.intercom", "loaded": true, "pid": 76201, "state": "active" },
            "worker": { "available": true, "label": "com.jarvis.worker", "loaded": true, "pid": 76209, "state": "active" }
          },
          "worker": {
            "agent": "codex",
            "base_url": "http://localhost:8780",
            "probe": {
              "health": {
                "agent": "codex",
                "browser_enabled": true,
                "gui_provider_configured": false,
                "ok": true,
                "repo_root_configured": false,
                "workspace": "jarvis-workspace/worker"
              },
              "jobs": {
                "recent": [],
                "running": 0,
                "total": 0
              },
              "reachable": true
            },
            "workspace": "jarvis-workspace/worker"
          }
        }
        """

        let status = try FleetStatusParser.parse(data: Data(json.utf8))

        XCTAssertEqual(status.roles.first { $0.role == .brain }?.level, .green)
        XCTAssertEqual(status.roles.first { $0.role == .intercom }?.level, .green)
        XCTAssertEqual(status.roles.first { $0.role == .worker }?.level, .green)
        XCTAssertEqual(status.docker.level, .green)
        XCTAssertEqual(status.git.level, .green)
        XCTAssertEqual(status.git.branch, "Homebrew")
        XCTAssertEqual(status.git.revision, "installed")
        XCTAssertEqual(status.overall, .green)
    }
}
