import XCTest
@testable import Jarvis

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testUsesDefaultReleaseRepository() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertEqual(settings.appReleaseRepository, AppIdentity.releaseRepository)
        XCTAssertFalse(settings.jarvisPath.isEmpty)
        XCTAssertNil(defaults.string(forKey: "appReleaseRepository"))
    }

    @MainActor
    func testPreservesCustomReleaseRepository() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("roughcoder/custom-jarvis-releases", forKey: "appReleaseRepository")

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertEqual(settings.appReleaseRepository, "roughcoder/custom-jarvis-releases")
    }

    @MainActor
    func testAutoOpensSetupForFreshInstallOnce() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertTrue(settings.shouldAutoOpenSetup)
        settings.markSetupAutoOpened()
        XCTAssertFalse(settings.shouldAutoOpenSetup)
    }

    @MainActor
    func testDoesNotAutoOpenSetupWhenRolesAreConfigured() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(["brain"], forKey: "installedRoles")

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertFalse(settings.shouldAutoOpenSetup)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "JarvisTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test defaults suite")
            return (.standard, suiteName)
        }
        return (defaults, suiteName)
    }
}
