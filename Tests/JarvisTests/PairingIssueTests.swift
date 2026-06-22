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
    }
}
