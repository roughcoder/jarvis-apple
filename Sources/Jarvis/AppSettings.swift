import Foundation

struct JarvisConfiguration: Equatable {
    var jarvisRepoPath: String
    var uvPath: String
    var logsPath: String
    var installedRoles: Set<JarvisRole>
    var pollInterval: TimeInterval
    var dockerChecksEnabled: Bool
    var appReleaseRepository: String
    var appReleaseGitHubToken: String
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var jarvisRepoPath: String {
        didSet { save() }
    }

    @Published var uvPath: String {
        didSet { save() }
    }

    @Published var logsPath: String {
        didSet { save() }
    }

    @Published var installedRoles: Set<JarvisRole> {
        didSet { save() }
    }

    @Published var pollInterval: TimeInterval {
        didSet {
            pollInterval = max(2, min(pollInterval, 300))
            save()
        }
    }

    @Published var dockerChecksEnabled: Bool {
        didSet { save() }
    }

    @Published var appReleaseRepository: String {
        didSet { save() }
    }

    @Published var appReleaseGitHubToken: String {
        didSet { saveGitHubToken() }
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = .shared) {
        self.defaults = defaults
        self.keychain = keychain
        jarvisRepoPath = defaults.string(forKey: Keys.jarvisRepoPath)
            ?? Self.defaultJarvisRepoPath
        uvPath = defaults.string(forKey: Keys.uvPath)
            ?? Self.defaultUVPath
        logsPath = defaults.string(forKey: Keys.logsPath)
            ?? "~/Library/Logs/Jarvis"
        let roleNames = defaults.stringArray(forKey: Keys.installedRoles) ?? []
        installedRoles = Set(roleNames.compactMap(JarvisRole.init(rawValue:)))
        let storedPollInterval = defaults.double(forKey: Keys.pollInterval)
        pollInterval = storedPollInterval > 0 ? storedPollInterval : 5
        dockerChecksEnabled = defaults.object(forKey: Keys.dockerChecksEnabled) as? Bool ?? true
        let storedReleaseRepository = defaults.string(forKey: Keys.appReleaseRepository)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        appReleaseRepository = storedReleaseRepository == AppIdentity.legacyReleaseRepository
            ? AppIdentity.releaseRepository
            : storedReleaseRepository ?? AppIdentity.releaseRepository
        appReleaseGitHubToken = keychain.read(service: Keys.keychainService, account: Keys.githubTokenAccount) ?? ""

        if storedReleaseRepository == AppIdentity.legacyReleaseRepository {
            defaults.set(appReleaseRepository, forKey: Keys.appReleaseRepository)
        }
    }

    var configuration: JarvisConfiguration {
        JarvisConfiguration(
            jarvisRepoPath: jarvisRepoPath,
            uvPath: uvPath,
            logsPath: logsPath,
            installedRoles: installedRoles,
            pollInterval: pollInterval,
            dockerChecksEnabled: dockerChecksEnabled,
            appReleaseRepository: appReleaseRepository,
            appReleaseGitHubToken: appReleaseGitHubToken
        )
    }

    func setInstalled(_ installed: Bool, for role: JarvisRole) {
        if installed {
            installedRoles.insert(role)
        } else {
            installedRoles.remove(role)
        }
    }

    private func save() {
        defaults.set(jarvisRepoPath, forKey: Keys.jarvisRepoPath)
        defaults.set(uvPath, forKey: Keys.uvPath)
        defaults.set(logsPath, forKey: Keys.logsPath)
        defaults.set(installedRoles.map(\.rawValue).sorted(), forKey: Keys.installedRoles)
        defaults.set(pollInterval, forKey: Keys.pollInterval)
        defaults.set(dockerChecksEnabled, forKey: Keys.dockerChecksEnabled)
        defaults.set(appReleaseRepository, forKey: Keys.appReleaseRepository)
    }

    private func saveGitHubToken() {
        keychain.write(
            appReleaseGitHubToken.trimmingCharacters(in: .whitespacesAndNewlines),
            service: Keys.keychainService,
            account: Keys.githubTokenAccount
        )
    }

    private enum Keys {
        static let jarvisRepoPath = "jarvisRepoPath"
        static let uvPath = "uvPath"
        static let logsPath = "logsPath"
        static let installedRoles = "installedRoles"
        static let pollInterval = "pollInterval"
        static let dockerChecksEnabled = "dockerChecksEnabled"
        static let appReleaseRepository = "appReleaseRepository"
        static let keychainService = AppIdentity.keychainService
        static let githubTokenAccount = "github-release-token"
    }

    private static var defaultJarvisRepoPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Development/jarvis",
            "\(home)/jarvis"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "\(home)/Development/jarvis"
    }

    private static var defaultUVPath: String {
        [
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
            "/usr/bin/uv"
        ].first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/uv"
    }
}
