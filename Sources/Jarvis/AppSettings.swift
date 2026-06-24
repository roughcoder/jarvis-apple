import Foundation

struct JarvisConfiguration: Equatable {
    var jarvisRepoPath: String
    var jarvisPath: String
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

    @Published var jarvisPath: String {
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

    @Published var pairingBrainHost: String {
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

    @Published var setupCompleted: Bool {
        didSet { save() }
    }

    @Published var setupCompletedAt: Date? {
        didSet { save() }
    }

    @Published var setupLastStep: Int {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(defaults: UserDefaults = AppSettings.defaultUserDefaults(), keychain: KeychainStore = .shared) {
        self.defaults = defaults
        self.keychain = keychain
        let environment = ProcessInfo.processInfo.environment
        jarvisRepoPath = environment[Keys.envJarvisRepoPath] ?? defaults.string(forKey: Keys.jarvisRepoPath)
            ?? Self.defaultJarvisRepoPath
        jarvisPath = environment[Keys.envJarvisPath] ?? defaults.string(forKey: Keys.jarvisPath)
            ?? Self.defaultJarvisPath
        uvPath = environment[Keys.envUVPath] ?? defaults.string(forKey: Keys.uvPath)
            ?? Self.defaultUVPath
        logsPath = environment[Keys.envLogsPath] ?? defaults.string(forKey: Keys.logsPath)
            ?? "~/Library/Logs/Jarvis"
        let roleNames = defaults.stringArray(forKey: Keys.installedRoles) ?? []
        installedRoles = Set(roleNames.compactMap(JarvisRole.init(rawValue:)))
        pairingBrainHost = defaults.string(forKey: Keys.pairingBrainHost) ?? ""
        let storedPollInterval = defaults.double(forKey: Keys.pollInterval)
        pollInterval = storedPollInterval > 0 ? storedPollInterval : 5
        dockerChecksEnabled = defaults.object(forKey: Keys.dockerChecksEnabled) as? Bool ?? true
        let storedReleaseRepository = defaults.string(forKey: Keys.appReleaseRepository)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        appReleaseRepository = storedReleaseRepository ?? AppIdentity.releaseRepository
        appReleaseGitHubToken = keychain.read(service: Keys.keychainService, account: Keys.githubTokenAccount) ?? ""
        setupCompleted = defaults.bool(forKey: Keys.setupCompleted)
        setupCompletedAt = defaults.object(forKey: Keys.setupCompletedAt) as? Date
        setupLastStep = defaults.object(forKey: Keys.setupLastStep) as? Int ?? 0
    }

    var shouldAutoOpenSetup: Bool {
        !setupCompleted
    }

    var configuration: JarvisConfiguration {
        JarvisConfiguration(
            jarvisRepoPath: jarvisRepoPath,
            jarvisPath: jarvisPath,
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

    func markSetupAutoOpened() {
        defaults.set(true, forKey: Keys.didAutoOpenSetup)
    }

    func markSetupCompleted(step: Int) {
        setupCompleted = true
        setupCompletedAt = Date()
        setupLastStep = step
    }

    func rememberSetupStep(_ step: Int) {
        setupLastStep = step
    }

    func resetInstalledState() {
        installedRoles = []
        pairingBrainHost = ""
        jarvisRepoPath = ""
        defaults.set(false, forKey: Keys.didAutoOpenSetup)
        setupCompleted = false
        setupCompletedAt = nil
        setupLastStep = 0
    }

    private func save() {
        defaults.set(jarvisRepoPath, forKey: Keys.jarvisRepoPath)
        defaults.set(jarvisPath, forKey: Keys.jarvisPath)
        defaults.set(uvPath, forKey: Keys.uvPath)
        defaults.set(logsPath, forKey: Keys.logsPath)
        defaults.set(installedRoles.map(\.rawValue).sorted(), forKey: Keys.installedRoles)
        defaults.set(pairingBrainHost.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.pairingBrainHost)
        defaults.set(pollInterval, forKey: Keys.pollInterval)
        defaults.set(dockerChecksEnabled, forKey: Keys.dockerChecksEnabled)
        defaults.set(appReleaseRepository, forKey: Keys.appReleaseRepository)
        defaults.set(setupCompleted, forKey: Keys.setupCompleted)
        if let setupCompletedAt {
            defaults.set(setupCompletedAt, forKey: Keys.setupCompletedAt)
        } else {
            defaults.removeObject(forKey: Keys.setupCompletedAt)
        }
        defaults.set(setupLastStep, forKey: Keys.setupLastStep)
    }

    private func saveGitHubToken() {
        keychain.write(
            appReleaseGitHubToken.trimmingCharacters(in: .whitespacesAndNewlines),
            service: Keys.keychainService,
            account: Keys.githubTokenAccount
        )
    }

    nonisolated private static func defaultUserDefaults() -> UserDefaults {
        let environment = ProcessInfo.processInfo.environment
        if let suiteName = environment[Keys.envDefaultsSuite],
           let defaults = UserDefaults(suiteName: suiteName)
        {
            return defaults
        }
        return .standard
    }

    private enum Keys {
        static let jarvisRepoPath = "jarvisRepoPath"
        static let jarvisPath = "jarvisPath"
        static let uvPath = "uvPath"
        static let logsPath = "logsPath"
        static let installedRoles = "installedRoles"
        static let pairingBrainHost = "pairingBrainHost"
        static let pollInterval = "pollInterval"
        static let dockerChecksEnabled = "dockerChecksEnabled"
        static let appReleaseRepository = "appReleaseRepository"
        static let didAutoOpenSetup = "didAutoOpenSetup"
        static let setupCompleted = "setupCompleted"
        static let setupCompletedAt = "setupCompletedAt"
        static let setupLastStep = "setupLastStep"
        static let keychainService = AppIdentity.keychainService
        static let githubTokenAccount = "github-release-token"
        static let envDefaultsSuite = "JARVIS_APP_DEFAULTS_SUITE"
        static let envJarvisRepoPath = "JARVIS_APP_JARVIS_REPO_PATH"
        static let envJarvisPath = "JARVIS_APP_JARVIS_PATH"
        static let envUVPath = "JARVIS_APP_UV_PATH"
        static let envLogsPath = "JARVIS_APP_LOGS_PATH"
    }

    private static var defaultJarvisRepoPath: String {
        ""
    }

    private static var defaultUVPath: String {
        [
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
            "/usr/bin/uv"
        ].first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/uv"
    }

    private static var defaultJarvisPath: String {
        [
            "/opt/homebrew/bin/jarvis",
            "/usr/local/bin/jarvis"
        ].first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/jarvis"
    }
}
