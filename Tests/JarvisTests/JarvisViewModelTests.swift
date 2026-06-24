import XCTest
@testable import Jarvis

final class JarvisViewModelTests: XCTestCase {
    @MainActor
    func testSelectedServicesHealthyRequiresGreenSelectedRoles() {
        let (settings, defaults) = makeSettings()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        settings.installedRoles = [.brain, .worker]
        let viewModel = JarvisViewModel(settings: settings)
        viewModel.fleetStatus = fleetStatus(
            roles: [
                role(.brain, .green),
                role(.intercom, .green),
                role(.worker, .amber)
            ]
        )

        XCTAssertFalse(viewModel.selectedServicesAreHealthy)

        viewModel.fleetStatus = fleetStatus(
            roles: [
                role(.brain, .green),
                role(.intercom, .amber),
                role(.worker, .green)
            ]
        )

        XCTAssertTrue(viewModel.selectedServicesAreHealthy)
    }

    @MainActor
    func testSelectedServicesHealthyRequiresRolesConfigured() {
        let (settings, defaults) = makeSettings()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let viewModel = JarvisViewModel(settings: settings)
        viewModel.fleetStatus = fleetStatus(
            roles: [
                role(.brain, .green),
                role(.intercom, .green),
                role(.worker, .green)
            ]
        )

        XCTAssertFalse(viewModel.selectedServicesAreHealthy)
    }

    @MainActor
    func testMissingLaunchdServiceAcceptsBootoutInputOutputError() {
        let (settings, defaults) = makeSettings()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let viewModel = JarvisViewModel(settings: settings)

        XCTAssertTrue(viewModel.isMissingLaunchdService("""
        Boot-out failed: 5: Input/output error
        Try re-running the command as root for richer errors.
        """))
        XCTAssertTrue(viewModel.isMissingLaunchdService("Could not find specified service"))
        XCTAssertTrue(viewModel.isMissingLaunchdService("No such process"))
        XCTAssertFalse(viewModel.isMissingLaunchdService("Operation not permitted"))
    }

    @MainActor
    func testInstallSelectedServicesReturnsFalseWhenSyncFails() async throws {
        let (settings, defaults) = makeSettings()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let checkout = try makeCheckout()
        defer { try? FileManager.default.removeItem(at: checkout) }
        settings.jarvisRepoPath = checkout.path
        settings.uvPath = "/usr/bin/false"
        settings.installedRoles = [.brain]
        let viewModel = JarvisViewModel(settings: settings)

        let installed = await viewModel.installSelectedServices()

        XCTAssertFalse(installed)
        XCTAssertNotNil(viewModel.lastError)
        XCTAssertTrue(viewModel.lastCommandOutput.contains("ERROR:"))
    }

    private func role(_ role: JarvisRole, _ level: StatusLevel) -> RoleStatus {
        RoleStatus(role: role, level: level, headline: level.title, detail: level.title, loaded: level == .green)
    }

    private func fleetStatus(roles: [RoleStatus]) -> FleetStatus {
        FleetStatus(
            version: "test",
            deviceID: "local-mac",
            platform: "Darwin",
            roles: roles,
            docker: DockerStatus(level: .green, headline: "Healthy", detail: "Healthy"),
            git: GitStatus(level: .green, branch: "main", revision: "abc123", dirty: false, detail: "Healthy"),
            pairing: PairingSummary(identity: "house", scope: "house", capabilityCount: 0, detail: "house"),
            worker: WorkerSummary(runningJobs: 0, recentStatuses: [], detail: "idle"),
            overall: roles.map(\.level).max { $0.rank < $1.rank } ?? .unknown,
            rawJSON: "{}",
            lastUpdated: Date()
        )
    }

    @MainActor
    private func makeSettings() -> (AppSettings, UserDefaults) {
        let suiteName = "JarvisViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(suiteName, forKey: "testSuiteName")
        return (AppSettings(defaults: defaults, keychain: KeychainStore()), defaults)
    }

    private func makeCheckout() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JarvisViewModelCheckout-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("src/jarvis"),
            withIntermediateDirectories: true
        )
        try "name = \"jarvis\"\n".write(
            to: directory.appendingPathComponent("pyproject.toml"),
            atomically: true,
            encoding: .utf8
        )
        try "# test marker\n".write(
            to: directory.appendingPathComponent("src/jarvis/cli.py"),
            atomically: true,
            encoding: .utf8
        )
        return directory
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: "testSuiteName")!
    }
}
