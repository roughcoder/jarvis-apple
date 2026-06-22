import AppKit
import XCTest
@testable import Jarvis

final class AppIdentityTests: XCTestCase {
    func testApplePlatformBundleIdentifiersAreExplicit() {
        XCTAssertEqual(AppIdentity.menuBarSymbolName, "brain.head.profile")
        XCTAssertEqual(AppIdentity.macOSBundleIdentifier, "dev.infinitestack.jarvis.mac")
        XCTAssertEqual(AppIdentity.iOSBundleIdentifier, "dev.infinitestack.jarvis.ios")
        XCTAssertEqual(AppIdentity.bundleIdentifier, AppIdentity.macOSBundleIdentifier)
        XCTAssertEqual(AppIdentity.keychainService, AppIdentity.macOSBundleIdentifier)
    }

    func testMenuBarSymbolIsAvailableOnCurrentMacOS() {
        XCTAssertNotNil(NSImage(systemSymbolName: AppIdentity.menuBarSymbolName, accessibilityDescription: nil))
    }
}
