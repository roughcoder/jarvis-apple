import XCTest
@testable import Jarvis

final class AppIdentityTests: XCTestCase {
    func testApplePlatformBundleIdentifiersAreExplicit() {
        XCTAssertEqual(AppIdentity.menuBarSymbolName, "robot")
        XCTAssertEqual(AppIdentity.macOSBundleIdentifier, "dev.infinitestack.jarvis.mac")
        XCTAssertEqual(AppIdentity.iOSBundleIdentifier, "dev.infinitestack.jarvis.ios")
        XCTAssertEqual(AppIdentity.bundleIdentifier, AppIdentity.macOSBundleIdentifier)
        XCTAssertEqual(AppIdentity.keychainService, AppIdentity.macOSBundleIdentifier)
    }
}
