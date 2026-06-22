import XCTest
@testable import JarvisMenuBar

final class RedactorTests: XCTestCase {
    func testRedactsSensitiveTextValues() {
        let input = """
        token=abc123
        api_key: "sk-test"
        harmless=value
        """

        let output = Redactor.redactText(input)

        XCTAssertFalse(output.contains("abc123"))
        XCTAssertFalse(output.contains("sk-test"))
        XCTAssertTrue(output.contains("harmless=value"))
    }

    func testRedactsNestedJSONObject() {
        let object: JSONDictionary = [
            "worker": [
                "token": "secret",
                "status": "ok"
            ]
        ]

        let output = Redactor.redactedJSONString(from: object)

        XCTAssertFalse(output.contains("secret"))
        XCTAssertTrue(output.contains("<redacted>"))
        XCTAssertTrue(output.contains("ok"))
    }

    func testTextRedactionKeepsJSONParseable() throws {
        let input = #"{"pairing_token":"secret-token","status":"ok"}"#

        let output = Redactor.redactText(input)
        let data = try XCTUnwrap(output.data(using: .utf8))
        let object = try JSONValue.dictionary(from: data)

        XCTAssertEqual(object.string("pairing_token"), "<redacted>")
        XCTAssertEqual(object.string("status"), "ok")
    }
}
