import XCTest
@testable import Jarvis

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testUsesDefaultReleaseRepository() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertEqual(settings.appReleaseRepository, AppIdentity.releaseRepository)
        XCTAssertEqual(settings.jarvisRepoPath, "")
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
    func testPersistsPairingBrainHost() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())
        settings.pairingBrainHost = " imac.private "

        XCTAssertEqual(defaults.string(forKey: "pairingBrainHost"), "imac.private")
    }

    @MainActor
    func testResetInstalledStateClearsPackagedInstallState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())
        settings.installedRoles = [.brain, .worker]
        settings.pairingBrainHost = "100.76.46.92"
        settings.jarvisRepoPath = "/Users/neilbarton/Development/jarvis"
        settings.markSetupAutoOpened()

        settings.resetInstalledState()

        XCTAssertEqual(settings.installedRoles, [])
        XCTAssertEqual(settings.pairingBrainHost, "")
        XCTAssertEqual(settings.jarvisRepoPath, "")
        XCTAssertTrue(settings.shouldAutoOpenSetup)
        XCTAssertEqual(defaults.stringArray(forKey: "installedRoles"), [])
        XCTAssertEqual(defaults.string(forKey: "pairingBrainHost"), "")
        XCTAssertEqual(defaults.string(forKey: "jarvisRepoPath"), "")
        XCTAssertFalse(defaults.bool(forKey: "didAutoOpenSetup"))
    }

    @MainActor
    func testAutoOpensSetupForFreshInstallOnce() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults, keychain: KeychainStore())

        XCTAssertTrue(settings.shouldAutoOpenSetup)
        settings.markSetupCompleted(step: 6)
        XCTAssertFalse(settings.shouldAutoOpenSetup)
        XCTAssertTrue(defaults.bool(forKey: "setupCompleted"))
        XCTAssertEqual(defaults.integer(forKey: "setupLastStep"), 6)
    }

    @MainActor
    func testDoesNotAutoOpenSetupWhenRolesAreConfigured() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(["brain"], forKey: "installedRoles")
        defaults.set(true, forKey: "setupCompleted")

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
