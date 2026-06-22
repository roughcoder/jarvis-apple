import XCTest
@testable import Jarvis

final class HomebrewRuntimeClientTests: XCTestCase {
    func testParsesInstalledFormulaVersion() {
        XCTAssertEqual(
            HomebrewRuntimeClient.version(from: "jarvis 0.1.0\n", token: "jarvis"),
            "0.1.0"
        )
    }

    func testMissingFormulaVersionReturnsNil() {
        XCTAssertNil(HomebrewRuntimeClient.version(from: "other 1.0.0\n", token: "jarvis"))
    }
}
