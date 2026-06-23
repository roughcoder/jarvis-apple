import XCTest
@testable import Jarvis

final class PairingIssueTests: XCTestCase {
    func testParsesPairingIssueJSON() throws {
        let json = """
        {
          "token": "abc123",
          "brain_devices_entry": "{\\"token\\":\\"abc123\\",\\"device_id\\":\\"kitchen-pi\\"}"
        }
        """

        let issue = try PairingIssueParser.parse(data: Data(json.utf8))

        XCTAssertEqual(issue.token, "abc123")
        XCTAssertTrue(issue.brainDevicesEntry.contains("kitchen-pi"))
        XCTAssertNil(issue.brainConfigPath)
        XCTAssertNil(issue.brainDevicesCount)
        XCTAssertNil(issue.macConfigCommand)
        XCTAssertNil(issue.piInstallerCommand)
    }

    func testParsesOptionalBrainConfigUpdateFields() throws {
        let json = """
        {
          "token": "abc123",
          "brain_devices_entry": "{\\"token\\":\\"abc123\\",\\"device_id\\":\\"kitchen-pi\\"}",
          "brain_config_path": "/Users/neil/.jarvis/.env",
          "brain_devices_count": 3
        }
        """

        let issue = try PairingIssueParser.parse(data: Data(json.utf8))

        XCTAssertEqual(issue.brainConfigPath, "/Users/neil/.jarvis/.env")
        XCTAssertEqual(issue.brainDevicesCount, 3)
    }

    func testParsesOptionalPiInstallerCommand() throws {
        let json = """
        {
          "token": "abc123",
          "brain_devices_entry": "{\\"token\\":\\"abc123\\",\\"device_id\\":\\"kitchen-pi\\"}",
          "pi_installer_command": "curl -fsSL https://example.invalid/install.sh"
        }
        """

        let issue = try PairingIssueParser.parse(data: Data(json.utf8))

        XCTAssertEqual(issue.piInstallerCommand, "curl -fsSL https://example.invalid/install.sh")
    }

    func testParsesOptionalMacConfigCommand() throws {
        let json = """
        {
          "token": "abc123",
          "brain_devices_entry": "{\\"token\\":\\"abc123\\",\\"device_id\\":\\"neil-laptop\\"}",
          "mac_config_command": "mkdir -p ~/.jarvis"
        }
        """

        let issue = try PairingIssueParser.parse(data: Data(json.utf8))

        XCTAssertEqual(issue.macConfigCommand, "mkdir -p ~/.jarvis")
    }
}
