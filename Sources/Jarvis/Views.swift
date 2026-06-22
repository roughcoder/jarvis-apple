import AppKit
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel
    @Environment(\.openSettings) private var openSettings
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
                    openSettings()
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
                SecureField("GitHub token for private releases", text: $settings.appReleaseGitHubToken)
                    .textFieldStyle(.roundedBorder)
                Text("Use owner/repo, for example \(AppIdentity.releaseRepository). Private repositories need a token with repo release read access.")
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
