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
        XCTAssertNil(issue.piInstallerCommand)
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
}
