import AppKit
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 10) {
                ServiceSectionHeader(title: "Local services", detail: installedRolesSummary)
                ForEach(viewModel.fleetStatus.roles) { status in
                    RoleRow(status: status)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ServiceSectionHeader(title: "Infrastructure", detail: settings.dockerChecksEnabled ? "Docker checks enabled" : "Docker checks paused")
                DockerRow(status: viewModel.fleetStatus.docker)
            }

            summaryGrid
            appRelease
            commandState
            quickActions
        }
        .padding(16)
        .frame(width: 460)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    StatusPill(level: viewModel.fleetStatus.overall, text: viewModel.fleetStatus.overall.title)
                    Text(healthSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(AppIdentity.displayName)
                    .font(.title3.weight(.semibold))

                Text(deviceSummary)
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

    private var summaryGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                SummaryTile(
                    icon: "person.line.dotted.person.fill",
                    title: "Pairing",
                    value: viewModel.fleetStatus.pairing.detail
                )
                SummaryTile(
                    icon: "hammer.fill",
                    title: "Worker",
                    value: viewModel.fleetStatus.worker.detail
                )
            }
        }
    }

    private var appRelease: some View {
        VStack(alignment: .leading, spacing: 10) {
            ServiceSectionHeader(title: "App release", detail: "Current \(viewModel.currentAppVersion)")

            HStack(alignment: .center, spacing: 10) {
                SummaryTile(
                    icon: "arrow.down.app.fill",
                    title: viewModel.appReleaseStatus,
                    value: viewModel.homebrewCaskStatus == nil ? "Direct install updates" : "Homebrew-managed updates"
                )

                Spacer(minLength: 8)

                HStack(spacing: 6) {
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
        HStack(spacing: 8) {
            Button {
                openWindow(id: "command-progress")
                Task { await viewModel.updateInstalledRoles() }
            } label: {
                Label("Update runtime", systemImage: "arrow.down.circle")
            }
            .disabled(viewModel.isBusy || settings.installedRoles.isEmpty)

            Button {
                openWindow(id: "command-progress")
            } label: {
                Label("Output", systemImage: "terminal")
            }

            Spacer(minLength: 8)

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

            Menu {
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

                Divider()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var healthSummary: String {
        let levels = viewModel.fleetStatus.roles.map(\.level) + [viewModel.fleetStatus.docker.level]
        let down = levels.filter { $0 == .red }.count
        let degraded = levels.filter { $0 == .amber }.count
        let unknown = levels.filter { $0 == .unknown }.count
        if down > 0 || degraded > 0 || unknown > 0 {
            return [
                down > 0 ? "\(down) down" : nil,
                degraded > 0 ? "\(degraded) degraded" : nil,
                unknown > 0 ? "\(unknown) unknown" : nil
            ].compactMap { $0 }.joined(separator: " · ")
        }
        return "All watched systems healthy"
    }

    private var deviceSummary: String {
        "\(viewModel.fleetStatus.deviceID) · \(viewModel.fleetStatus.git.branch) @ \(viewModel.fleetStatus.git.revision)"
    }

    private var installedRolesSummary: String {
        if settings.installedRoles.isEmpty {
            return "No local roles selected"
        }
        return settings.installedRoles
            .sorted { $0.title < $1.title }
            .map(\.title)
            .joined(separator: ", ")
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
                    .disabled(settings.installedRoles.isEmpty || viewModel.isBusy || viewModel.selectedServicesAreHealthy)
                    .help(viewModel.selectedServicesAreHealthy ? "Selected services are healthy. Use Update Runtime or role controls if needed." : "Install or repair selected launchd services")

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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: status.level.symbolName)
                .foregroundStyle(status.level.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(status.role.title)
                        .font(.subheadline.weight(.semibold))
                    if !settings.installedRoles.contains(status.role) {
                        Text("Not installed")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text(serviceDetail(headline: status.headline, detail: status.detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    Task { await viewModel.performLaunchd(primaryAction, role: status.role) }
                } label: {
                    Label(primaryAction.menuTitle, systemImage: primaryAction.symbolName)
                }
                .disabled(viewModel.isBusy || !settings.installedRoles.contains(status.role))

                Menu {
                    Button {
                        Task { await viewModel.performLaunchd(.start, role: status.role) }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }

                    Button {
                        Task { await viewModel.performLaunchd(.restart, role: status.role) }
                    } label: {
                        Label("Restart", systemImage: "arrow.clockwise")
                    }

                    Button {
                        Task { await viewModel.performLaunchd(.stop, role: status.role) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }

                    Divider()

                    Button {
                        viewModel.openLog(for: status.role)
                    } label: {
                        Label("Open log", systemImage: "doc.text.magnifyingglass")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 18, height: 18)
                }
                .disabled(viewModel.isBusy || !settings.installedRoles.contains(status.role))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private var primaryAction: LaunchdAction {
        status.level == .green ? .restart : .start
    }
}

struct DockerRow: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel

    let status: DockerStatus

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: status.level.symbolName)
                .foregroundStyle(status.level.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("Docker")
                    .font(.subheadline.weight(.semibold))
                Text(serviceDetail(headline: status.headline, detail: status.detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Menu {
                Button {
                    Task { await viewModel.performDocker(.start) }
                } label: {
                    Label("Compose up", systemImage: "play.fill")
                }

                Button {
                    Task { await viewModel.performDocker(.restart) }
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }

                Button {
                    Task { await viewModel.performDocker(.stop) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } label: {
                Label(status.level == .green ? "Manage" : "Fix", systemImage: status.level == .green ? "slider.horizontal.3" : "wrench")
            }
            .disabled(viewModel.isBusy || !settings.dockerChecksEnabled)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

struct ServiceSectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer()
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

struct SummaryTile: View {
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
                    .lineLimit(1)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusPill: View {
    let level: StatusLevel
    let text: String

    var body: some View {
        Label(text, systemImage: level.symbolName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(level.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(level.color.opacity(0.12), in: Capsule())
    }
}

private func serviceDetail(headline: String, detail: String) -> String {
    if headline.caseInsensitiveCompare(detail) == .orderedSame {
        return headline
    }
    if detail.localizedCaseInsensitiveContains(headline) {
        return detail
    }
    return "\(headline) · \(detail)"
}

private extension LaunchdAction {
    var menuTitle: String {
        switch self {
        case .start:
            return "Start"
        case .restart:
            return "Restart"
        case .stop:
            return "Stop"
        case .printStatus:
            return "Status"
        }
    }

    var symbolName: String {
        switch self {
        case .start:
            return "play.fill"
        case .restart:
            return "arrow.clockwise"
        case .stop:
            return "stop.fill"
        case .printStatus:
            return "info.circle"
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

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedPane: SettingsPane = .runtime

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsHeader(title: selectedPane.title, detail: selectedPane.detail)
                    selectedPaneContent
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 760)
        .frame(minHeight: 520)
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsPane.allCases) { pane in
                Button {
                    selectedPane = pane
                } label: {
                    Label(pane.title, systemImage: pane.symbolName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selectedPane == pane ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedPane == pane ? .primary : .secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 150)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var selectedPaneContent: some View {
        switch selectedPane {
        case .runtime:
            SettingsGroup(title: "Runtime paths", detail: "Jarvis can run from an installed command or a development checkout.") {
                PathSettingRow(title: "Jarvis repo", path: $settings.jarvisRepoPath, selectsDirectory: true)
                PathSettingRow(title: "jarvis command", path: $settings.jarvisPath, selectsDirectory: false)
                PathSettingRow(title: "uv binary", path: $settings.uvPath, selectsDirectory: false)
                PathSettingRow(title: "Logs", path: $settings.logsPath, selectsDirectory: true)
            }
        case .roles:
            SettingsGroup(title: "Installed roles", detail: "Select the launchd services this Mac owns locally.") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(JarvisRole.allCases) { role in
                        RoleSettingsRow(role: role, isInstalled: Binding(
                            get: { settings.installedRoles.contains(role) },
                            set: { settings.setInstalled($0, for: role) }
                        ))
                    }
                }
            }
        case .fleet:
            SettingsGroup(title: "Pairing", detail: "Defaults used when issuing commands for Macs and Raspberry Pis.") {
                VStack(alignment: .leading, spacing: 12) {
                    FieldRow(title: "Brain host") {
                        TextField("imac.private", text: $settings.pairingBrainHost)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("Pairing tokens and install commands are generated from Setup. Secrets stay out of git and are redacted from command output.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .operations:
            SettingsGroup(title: "Polling", detail: "Control how often the menu refreshes status.") {
                Stepper(value: $settings.pollInterval, in: 2...300, step: 1) {
                    Text("Poll every \(Int(settings.pollInterval)) seconds")
                }
                Toggle("Enable Docker checks", isOn: $settings.dockerChecksEnabled)
            }
        case .updates:
            SettingsGroup(title: "App releases", detail: "Use public releases by default, or add a token for private checks.") {
                VStack(alignment: .leading, spacing: 12) {
                    FieldRow(title: "GitHub repo") {
                        TextField("GitHub repo", text: $settings.appReleaseRepository)
                            .textFieldStyle(.roundedBorder)
                    }
                    FieldRow(title: "GitHub token") {
                        SecureField("Optional", text: $settings.appReleaseGitHubToken)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Text("Use owner/repo, for example \(AppIdentity.releaseRepository). Public releases do not need a token.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case runtime
    case roles
    case fleet
    case operations
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runtime: "Runtime"
        case .roles: "Roles"
        case .fleet: "Fleet"
        case .operations: "Operations"
        case .updates: "Updates"
        }
    }

    var detail: String {
        switch self {
        case .runtime: "Where Jarvis runs from on this Mac."
        case .roles: "Which services this Mac should own."
        case .fleet: "Private-network pairing defaults."
        case .operations: "Refresh and Docker behavior."
        case .updates: "App release source and credentials."
        }
    }

    var symbolName: String {
        switch self {
        case .runtime: "terminal"
        case .roles: "switch.2"
        case .fleet: "network"
        case .operations: "timer"
        case .updates: "arrow.down.app"
        }
    }
}

struct SettingsHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

struct FieldRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)
            content
        }
    }
}

struct RoleSettingsRow: View {
    let role: JarvisRole
    @Binding var isInstalled: Bool

    var body: some View {
        Toggle(isOn: $isInstalled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(role.title)
                    .font(.subheadline.weight(.semibold))
                Text(role.settingsDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
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
        FieldRow(title: title) {
            HStack(spacing: 8) {
                TextField(title, text: $path)
                    .textFieldStyle(.roundedBorder)

                PathStatusLabel(path: path, selectsDirectory: selectsDirectory)

                Button {
                    choosePath()
                } label: {
                    Image(systemName: "ellipsis")
                }
                .help("Choose \(title)")
            }
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

struct PathStatusLabel: View {
    let path: String
    let selectsDirectory: Bool

    var body: some View {
        Label(statusText, systemImage: statusSymbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor)
            .labelStyle(.iconOnly)
            .help(statusText)
    }

    private var statusText: String {
        if selectsDirectory {
            return fileManager.fileExists(atPath: expandedPath) ? "Folder found" : "Folder missing"
        }
        return fileManager.isExecutableFile(atPath: expandedPath) ? "Executable found" : "Executable missing"
    }

    private var statusSymbol: String {
        if selectsDirectory {
            return fileManager.fileExists(atPath: expandedPath) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        }
        return fileManager.isExecutableFile(atPath: expandedPath) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        if selectsDirectory {
            return fileManager.fileExists(atPath: expandedPath) ? .green : .orange
        }
        return fileManager.isExecutableFile(atPath: expandedPath) ? .green : .orange
    }

    private var expandedPath: String {
        NSString(string: path).expandingTildeInPath
    }

    private var fileManager: FileManager {
        .default
    }
}

private extension JarvisRole {
    var settingsDescription: String {
        switch self {
        case .brain:
            return "Central voice brain and local service coordinator."
        case .intercom:
            return "Microphone, wake word, and speaker edge for this Mac."
        case .worker:
            return "Browser, GUI, shell, and coding worker for this Mac."
        }
    }
}
