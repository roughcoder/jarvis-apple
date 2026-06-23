import AppKit
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            roles
            DockerRow(status: viewModel.fleetStatus.docker)
            Divider()
            summaries
            appRelease
            commandState
            Divider()
            quickActions
        }
        .padding(14)
        .frame(width: 420)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusDot(level: viewModel.fleetStatus.overall)
                .frame(width: 13, height: 13)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppIdentity.displayName)
                    .font(.headline)
                Text("\(viewModel.fleetStatus.deviceID) · \(viewModel.fleetStatus.git.branch) @ \(viewModel.fleetStatus.git.revision)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh(includeDocker: true) }
            } label: {
                Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isRefreshing)
            .help("Refresh status")
        }
    }

    private var roles: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.fleetStatus.roles) { status in
                RoleRow(status: status)
            }
        }
    }

    private var summaries: some View {
        VStack(alignment: .leading, spacing: 8) {
            SummaryLine(
                icon: "person.line.dotted.person.fill",
                title: "Pairing",
                value: viewModel.fleetStatus.pairing.detail
            )
            SummaryLine(
                icon: "hammer.fill",
                title: "Worker",
                value: viewModel.fleetStatus.worker.detail
            )
        }
    }

    private var appRelease: some View {
        VStack(alignment: .leading, spacing: 8) {
            SummaryLine(
                icon: "arrow.down.app.fill",
                title: "App Release",
                value: "Current \(viewModel.currentAppVersion) · \(viewModel.appReleaseStatus)"
            )

            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.checkForAppRelease() }
                } label: {
                    Label("Check", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isCheckingAppRelease)

                Button {
                    openWindow(id: "command-progress")
                    Task { await viewModel.installLatestAppRelease() }
                } label: {
                    Label(viewModel.appReleaseActionTitle, systemImage: viewModel.appReleaseActionSymbol)
                }
                .disabled(viewModel.isInstallingAppRelease || !viewModel.canInstallAppRelease)

                Button {
                    viewModel.openLatestAppRelease()
                } label: {
                    Label("Release", systemImage: "safari")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var commandState: some View {
        if let activeOperation = viewModel.activeOperation {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(activeOperation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if let lastError = viewModel.lastError {
            Label(lastError, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(4)
        }

        if !viewModel.lastCommandOutput.isEmpty {
            DisclosureGroup {
                ScrollView {
                    Text(viewModel.lastCommandOutput)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .frame(maxHeight: 160)
            } label: {
                Text("Last command output")
                    .font(.caption)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    viewModel.openJarvisRepo()
                } label: {
                    Label("Repo", systemImage: "folder")
                }
                .disabled(settings.jarvisRepoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    viewModel.openLogsFolder()
                } label: {
                    Label("Logs", systemImage: "doc.text.magnifyingglass")
                }

                Button {
                    viewModel.copyStatusJSON()
                } label: {
                    Label("Copy JSON", systemImage: "doc.on.doc")
                }
            }

            HStack(spacing: 8) {
                Button {
                    openWindow(id: "command-progress")
                    Task { await viewModel.updateInstalledRoles() }
                } label: {
                    Label("Update", systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isBusy || settings.installedRoles.isEmpty)

                Spacer()

                Button {
                    openWindow(id: "command-progress")
                } label: {
                    Label("Output", systemImage: "terminal")
                }

                Button {
                    NSApplication.shared.activate()
                    openWindow(id: "setup")
                } label: {
                    Label("Setup", systemImage: "wand.and.stars")
                }

                Button {
                    AppWindowPresenter.openSettings(settings: settings)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct SetupGuideView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var setupProfile: SetupProfile = .custom

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jarvis Setup")
                        .font(.title2.weight(.semibold))
                    Text(settings.installedRoles.isEmpty ? "Choose roles for this Mac." : selectedRoleSummary)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await viewModel.refresh(includeDocker: true) }
                } label: {
                    Label("Check", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRefreshing)
            }

            setupChecks

            Divider()

            rolePicker

            Divider()

            pairingIssuer

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        AppWindowPresenter.openSettings(settings: settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    Button {
                        openWindow(id: "command-progress")
                        Task { await viewModel.installSelectedServices() }
                    } label: {
                        Label("Install Services", systemImage: "square.and.arrow.down")
                    }
                    .disabled(settings.installedRoles.isEmpty || viewModel.isBusy || viewModel.selectedServicesAreLoaded)
                    .help(viewModel.selectedServicesAreLoaded ? "Selected services are already installed. Use Clean Uninstall before reinstalling." : "Install selected launchd services")

                    Button {
                        openWindow(id: "command-progress")
                        Task { await viewModel.updateInstalledRoles() }
                    } label: {
                        Label("Update Runtime", systemImage: "arrow.down.circle")
                    }
                    .disabled(settings.installedRoles.isEmpty || viewModel.isBusy)

                    Spacer()
                }

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        openWindow(id: "command-progress")
                        Task { await viewModel.cleanUninstallLocalState() }
                    } label: {
                        Label("Clean Uninstall", systemImage: "trash")
                    }
                    .disabled(viewModel.isBusy)

                    Button {
                        openWindow(id: "command-progress")
                        Task { await viewModel.collectBringupEvidence() }
                    } label: {
                        Label("Collect Evidence", systemImage: "checklist")
                    }
                    .disabled(settings.installedRoles.isEmpty || viewModel.isBusy)

                    Button {
                        openWindow(id: "command-progress")
                        Task { await viewModel.summarizeBringupEvidence() }
                    } label: {
                        Label("Summarize Evidence", systemImage: "checkmark.seal")
                    }
                    .disabled(viewModel.isBusy)

                    Button {
                        viewModel.openEvidenceFolder()
                    } label: {
                        Label("Open Evidence Folder", systemImage: "folder")
                    }
                    .disabled(viewModel.isBusy)

                    Spacer()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
    }

    private var selectedRoleSummary: String {
        settings.installedRoles
            .sorted { $0.title < $1.title }
            .map(\.title)
            .joined(separator: ", ")
    }

    private var setupChecks: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 10) {
            SetupCheckRow(
                title: "Jarvis runtime",
                level: viewModel.fleetStatus.version == "unknown" ? .unknown : .green,
                detail: "Version \(viewModel.fleetStatus.version)"
            )
            SetupCheckRow(
                title: "Device",
                level: viewModel.fleetStatus.deviceID == "unknown" ? .unknown : .green,
                detail: viewModel.fleetStatus.deviceID
            )
            SetupCheckRow(
                title: "Pairing",
                level: viewModel.fleetStatus.pairing.identity == "unknown" ? .amber : .green,
                detail: viewModel.fleetStatus.pairing.detail
            )
            SetupCheckRow(
                title: "Git state",
                level: viewModel.fleetStatus.git.level,
                detail: viewModel.fleetStatus.git.detail
            )
        }
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Roles")
                .font(.headline)

            Picker("Setup profile", selection: $setupProfile) {
                ForEach(SetupProfile.allCases) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: setupProfile) { _, profile in
                apply(profile)
            }

            ForEach(JarvisRole.allCases) { role in
                Toggle(isOn: Binding(
                    get: { settings.installedRoles.contains(role) },
                    set: {
                        settings.setInstalled($0, for: role)
                        setupProfile = .custom
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(role.title)
                            .font(.subheadline.weight(.semibold))
                        Text(roleDescription(role))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var pairingIssuer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pair a Device")
                .font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Device id")
                        .font(.caption.weight(.semibold))
                    TextField("kitchen-pi", text: $viewModel.pairingDeviceID)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Identity")
                        .font(.caption.weight(.semibold))
                    TextField("optional personal owner", text: $viewModel.pairingIdentity)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Brain host")
                        .font(.caption.weight(.semibold))
                    TextField("imac.private", text: $settings.pairingBrainHost)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 10) {
                Button {
                    openWindow(id: "command-progress")
                    Task { await viewModel.checkWorkerReadiness() }
                } label: {
                    Label("Check Worker", systemImage: "display")
                }
                .disabled(viewModel.isBusy || !settings.installedRoles.contains(.worker))

                Button {
                    openWindow(id: "command-progress")
                    Task { await viewModel.checkPairingBrain() }
                } label: {
                    Label("Check Brain", systemImage: "network")
                }
                .disabled(viewModel.isBusy || settings.pairingBrainHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    openWindow(id: "command-progress")
                    Task { await viewModel.issuePairingToken() }
                } label: {
                    Label("Issue Token", systemImage: "key")
                }
                .disabled(viewModel.isBusy)

                Button {
                    viewModel.copyLatestPairingEntry()
                } label: {
                    Label("Copy Entry", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.latestPairingIssue == nil)

                Button {
                    viewModel.copyLatestMacConfigCommand()
                } label: {
                    Label("Copy Mac Config", systemImage: "laptopcomputer")
                }
                .disabled(viewModel.latestPairingIssue?.macConfigCommand == nil)

                Button {
                    viewModel.copyLatestPiInstallerCommand()
                } label: {
                    Label("Copy Pi Command", systemImage: "terminal")
                }
                .disabled(viewModel.latestPairingIssue?.piInstallerCommand == nil)
            }
            .buttonStyle(.bordered)

            if let latestPairingIssue = viewModel.latestPairingIssue {
                VStack(alignment: .leading, spacing: 8) {
                    PairingOutputBlock(text: latestPairingIssue.brainDevicesEntry)
                    if let macConfigCommand = latestPairingIssue.macConfigCommand {
                        PairingOutputBlock(text: macConfigCommand)
                    }
                    if let piInstallerCommand = latestPairingIssue.piInstallerCommand {
                        PairingOutputBlock(text: piInstallerCommand)
                    }
                }
            }
        }
    }

    private func roleDescription(_ role: JarvisRole) -> String {
        switch role {
        case .brain:
            "Central voice brain and local service coordinator."
        case .intercom:
            "Microphone, wake word, and speaker edge for this Mac."
        case .worker:
            "Browser, GUI, shell, and coding worker for this Mac."
        }
    }

    private func apply(_ profile: SetupProfile) {
        guard profile != .custom else {
            return
        }
        settings.installedRoles = profile.roles
        if !profile.defaultPairingDeviceID.isEmpty {
            viewModel.pairingDeviceID = profile.defaultPairingDeviceID
        }
        if !profile.defaultIdentity.isEmpty {
            viewModel.pairingIdentity = profile.defaultIdentity
        }
    }
}

enum SetupProfile: String, CaseIterable, Identifiable {
    case brainMac
    case laptop
    case workerOnly
    case roomPi
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brainMac: "Brain Mac"
        case .laptop: "Laptop"
        case .workerOnly: "Worker"
        case .roomPi: "Room Pi"
        case .custom: "Custom"
        }
    }

    var roles: Set<JarvisRole> {
        switch self {
        case .brainMac: [.brain, .worker, .intercom]
        case .laptop: [.intercom, .worker]
        case .workerOnly: [.worker]
        case .roomPi: []
        case .custom: []
        }
    }

    var defaultPairingDeviceID: String {
        switch self {
        case .roomPi: "room-pi"
        case .laptop: "laptop"
        case .brainMac, .workerOnly, .custom: ""
        }
    }

    var defaultIdentity: String {
        switch self {
        case .laptop: NSUserName()
        case .brainMac, .workerOnly, .roomPi, .custom: ""
        }
    }
}

struct PairingOutputBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct SetupCheckRow: View {
    let title: String
    let level: StatusLevel
    let detail: String

    var body: some View {
        GridRow {
            StatusDot(level: level)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct RoleRow: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel

    let status: RoleStatus

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            StatusDot(level: status.level)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.role.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(status.headline) · \(status.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                IconButton(symbol: "play.fill", help: "Start \(status.role.title)") {
                    Task { await viewModel.performLaunchd(.start, role: status.role) }
                }
                IconButton(symbol: "arrow.clockwise", help: "Restart \(status.role.title)") {
                    Task { await viewModel.performLaunchd(.restart, role: status.role) }
                }
                IconButton(symbol: "stop.fill", help: "Stop \(status.role.title)") {
                    Task { await viewModel.performLaunchd(.stop, role: status.role) }
                }
                IconButton(symbol: "doc.text.magnifyingglass", help: "Open \(status.role.title) log") {
                    viewModel.openLog(for: status.role)
                }
            }
            .disabled(viewModel.isBusy || !settings.installedRoles.contains(status.role))
        }
    }
}

struct DockerRow: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel

    let status: DockerStatus

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            StatusDot(level: status.level)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("Docker")
                    .font(.subheadline.weight(.semibold))
                Text("\(status.headline) · \(status.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                IconButton(symbol: "play.fill", help: "Docker compose up") {
                    Task { await viewModel.performDocker(.start) }
                }
                IconButton(symbol: "arrow.clockwise", help: "Docker compose restart") {
                    Task { await viewModel.performDocker(.restart) }
                }
                IconButton(symbol: "stop.fill", help: "Docker compose stop") {
                    Task { await viewModel.performDocker(.stop) }
                }
            }
            .disabled(viewModel.isBusy || !settings.dockerChecksEnabled)
        }
    }
}

struct SummaryLine: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct StatusDot: View {
    let level: StatusLevel

    var body: some View {
        Circle()
            .fill(level.color)
            .overlay {
                Circle().stroke(.quaternary, lineWidth: 1)
            }
            .accessibilityLabel(level.title)
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Paths") {
                PathSettingRow(title: "Jarvis repo", path: $settings.jarvisRepoPath, selectsDirectory: true)
                PathSettingRow(title: "jarvis command", path: $settings.jarvisPath, selectsDirectory: false)
                PathSettingRow(title: "uv binary", path: $settings.uvPath, selectsDirectory: false)
                PathSettingRow(title: "Logs", path: $settings.logsPath, selectsDirectory: true)
            }

            Section("Installed roles") {
                ForEach(JarvisRole.allCases) { role in
                    Toggle(role.title, isOn: Binding(
                        get: { settings.installedRoles.contains(role) },
                        set: { settings.setInstalled($0, for: role) }
                    ))
                }
            }

            Section("Polling") {
                Stepper(value: $settings.pollInterval, in: 2...300, step: 1) {
                    Text("Poll every \(Int(settings.pollInterval)) seconds")
                }
                Toggle("Enable Docker checks", isOn: $settings.dockerChecksEnabled)
            }

            Section("App releases") {
                TextField("GitHub repo", text: $settings.appReleaseRepository)
                    .textFieldStyle(.roundedBorder)
                SecureField("GitHub token (optional)", text: $settings.appReleaseGitHubToken)
                    .textFieldStyle(.roundedBorder)
                Text("Use owner/repo, for example \(AppIdentity.releaseRepository). Public releases do not need a token.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 560)
    }
}

struct CommandProgressWindow: View {
    @EnvironmentObject private var viewModel: JarvisViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command Progress")
                        .font(.title3.weight(.semibold))
                    Text(viewModel.activeOperation ?? "No command is running")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.activeOperation != nil {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let lastError = viewModel.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            ScrollView {
                Text(viewModel.lastCommandOutput.isEmpty ? "Command output will appear here." : viewModel.lastCommandOutput)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(20)
    }
}

struct PathSettingRow: View {
    let title: String
    @Binding var path: String
    let selectsDirectory: Bool

    var body: some View {
        HStack {
            TextField(title, text: $path)
                .textFieldStyle(.roundedBorder)
            Button {
                choosePath()
            } label: {
                Image(systemName: "ellipsis")
            }
            .help("Choose \(title)")
        }
    }

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !selectsDirectory
        panel.canChooseDirectories = selectsDirectory
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = selectsDirectory
        if panel.runModal() == .OK, let url = panel.url {
            path = FilePath.abbreviatingHome(in: url.path)
        }
    }
}
