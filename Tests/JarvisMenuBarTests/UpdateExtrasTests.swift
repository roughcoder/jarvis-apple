import XCTest
@testable import JarvisMenuBar

final class UpdateExtrasTests: XCTestCase {
    func testUnionsRoleExtrasInStableOrder() {
        let extras = JarvisClient.syncExtras(for: [.intercom, .worker, .brain])

        XCTAssertEqual(extras, [
            "gateway",
            "tts",
            "stt",
            "vad",
            "wake",
            "memory",
            "mcp",
            "worker",
            "browser"
        ])
    }

    func testNoInstalledRolesHasNoExtras() {
        XCTAssertEqual(JarvisClient.syncExtras(for: []), [])
    }
}
