import XCTest
@testable import Jarvis

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testMigratesLegacyReleaseRepositoryDefault() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(AppIdentity.legacyReleaseRepository, forKey: "appReleaseRepository")

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertEqual(settings.appReleaseRepository, AppIdentity.releaseRepository)
        XCTAssertEqual(defaults.string(forKey: "appReleaseRepository"), AppIdentity.releaseRepository)
    }

    @MainActor
    func testPreservesCustomReleaseRepository() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("roughcoder/custom-jarvis-releases", forKey: "appReleaseRepository")

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertEqual(settings.appReleaseRepository, "roughcoder/custom-jarvis-releases")
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
