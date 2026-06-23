import Foundation
import XCTest
@testable import Jarvis

final class JarvisClientTests: XCTestCase {
    func testUsesInstalledJarvisCommandWhenNoCheckoutExists() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        let invocation = client.jarvisInvocation(arguments: ["fleet-status", "--json"])

        XCTAssertEqual(invocation.mode, .installed)
        XCTAssertEqual(invocation.executable, "/opt/homebrew/bin/jarvis")
        XCTAssertEqual(invocation.arguments, ["fleet-status", "--json"])
        XCTAssertNil(invocation.currentDirectory)
        XCTAssertEqual(
            client.serviceInstallArguments(role: .brain),
            [
                "service", "install", "brain",
                "--jarvis-bin", "/opt/homebrew/bin/jarvis",
                "--workdir", JarvisClient.defaultInstalledWorkdir
            ]
        )
    }

    func testUsesCheckoutWithUVWhenCheckoutMarkersExist() throws {
        let directory = try makeCheckout()
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: directory.path,
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/bin/echo"
        ))

        let invocation = client.jarvisInvocation(arguments: ["pair", "room-pi", "--json"])

        XCTAssertEqual(invocation.mode, .checkout)
        XCTAssertEqual(invocation.executable, "/bin/echo")
        XCTAssertEqual(invocation.arguments, ["run", "jarvis", "pair", "room-pi", "--json"])
        XCTAssertEqual(invocation.currentDirectory, directory.path)
        XCTAssertEqual(client.serviceInstallArguments(role: .worker), ["service", "install", "worker"])
    }

    func testPairingArgumentsIncludePiInstallerWhenBrainHostIsSet() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(
            client.pairingArguments(deviceID: "room-pi", identity: "neil", brainHost: " imac.private "),
            [
                "pair", "room-pi", "--json",
                "--identity", "neil",
                "--mac-config",
                "--pi-installer",
                "--brain-host", "imac.private"
            ]
        )
    }

    func testPairingArgumentsOmitPiInstallerWhenBrainHostIsBlank() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(
            client.pairingArguments(deviceID: "room-pi", identity: "", brainHost: " "),
            ["pair", "room-pi", "--json"]
        )
    }

    func testBrainStatusArgumentsIncludeHostAndPortOverrides() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(
            client.brainStatusArguments(host: " imac.private ", port: " 8701 "),
            ["status", "--json", "--brain-host", "imac.private", "--brain-port", "8701"]
        )
    }

    func testWorkerDoctorArguments() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(client.workerDoctorArguments(), ["worker", "--doctor"])
    }

    func testBringupArgumentsIncludeSelectedRolesHardwareAndBrainHost() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(
            client.bringupArguments(roles: [.intercom, .worker], brainHost: " imac.private "),
            [
                "bringup", "--json",
                "--role", "worker",
                "--role", "intercom",
                "--hardware",
                "--brain-host", "imac.private"
            ]
        )
    }

    func testBringupArgumentsCanRunWithoutBrainHost() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(
            client.bringupArguments(roles: [.brain], brainHost: " "),
            [
                "bringup", "--json",
                "--role", "brain",
                "--hardware"
            ]
        )
    }

    func testBringupArgumentsCanSaveEvidenceOutput() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(
            client.bringupArguments(
                roles: [.worker],
                brainHost: " ",
                outputPath: " ~/Desktop/jarvis-bringup-evidence "
            ),
            [
                "bringup", "--json",
                "--role", "worker",
                "--hardware",
                "--output", "~/Desktop/jarvis-bringup-evidence"
            ]
        )
    }

    func testBringupSummaryArgumentsUseFleetAcceptanceGate() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv"
        ))

        XCTAssertEqual(
            client.bringupSummaryArguments(evidencePath: " ~/Desktop/jarvis-bringup-evidence "),
            [
                "bringup-summary",
                "~/Desktop/jarvis-bringup-evidence",
                "--json",
                "--expect-role", "brain",
                "--expect-role", "worker",
                "--expect-role", "intercom",
                "--min-files", "4"
            ]
        )
    }

    func testInstalledRoleSyncUsesJarvisServiceSync() {
        let client = JarvisClient(configuration: configuration(
            jarvisRepoPath: "/no/such/jarvis-checkout",
            jarvisPath: "/opt/homebrew/bin/jarvis",
            uvPath: "/no/such/uv",
            installedRoles: [.intercom, .brain]
        ))

        XCTAssertEqual(
            client.serviceSyncArguments(roles: JarvisClient.orderedInstalledRoles(for: client.configuration.installedRoles)),
            ["service", "sync", "brain", "intercom"]
        )
    }

    private func configuration(
        jarvisRepoPath: String,
        jarvisPath: String,
        uvPath: String,
        installedRoles: Set<JarvisRole> = []
    ) -> JarvisConfiguration {
        JarvisConfiguration(
            jarvisRepoPath: jarvisRepoPath,
            jarvisPath: jarvisPath,
            uvPath: uvPath,
            logsPath: "~/Library/Logs/Jarvis",
            installedRoles: installedRoles,
            pollInterval: 5,
            dockerChecksEnabled: true,
            appReleaseRepository: AppIdentity.releaseRepository,
            appReleaseGitHubToken: ""
        )
    }

    private func makeCheckout() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JarvisClientTests-\(UUID().uuidString)")
        let sourceDirectory = directory.appendingPathComponent("src/jarvis", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: directory.appendingPathComponent("pyproject.toml").path, contents: Data())
        FileManager.default.createFile(atPath: sourceDirectory.appendingPathComponent("cli.py").path, contents: Data())
        return directory
    }
}
