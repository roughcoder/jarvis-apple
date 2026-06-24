import AppKit
import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: JarvisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = SetupState.empty
    @State private var stepIndex = 0
    @State private var loaded = false
    @State private var isApplying = false
    @State private var statusText = ""
    @State private var errorText: String?
    @State private var applyResult: SetupApplyResult?
    @State private var validation: SetupValidation?
    @State private var whatsappAuthResult: WhatsAppAuthResult?
    @State private var uiTestCommand = ""

    private let steps = SetupWizardStep.allCases

    var body: some View {
        HStack(spacing: 0) {
            setupRail
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if uiTestControlsEnabled {
                            uiTestControlStrip
                        }
                        stepContent
                            .padding(28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Divider()
                footer
            }
        }
        .frame(minWidth: 840, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("setup.wizard")
        .task {
            await loadExistingSetup()
        }
        .onChange(of: stepIndex) { _, newValue in
            settings.rememberSetupStep(newValue)
        }
    }

    private var setupRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "switch.2")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                Text("Jarvis Setup")
                    .font(.title3.weight(.semibold))
                Text(settings.setupCompleted ? "Edit this machine's configuration." : "Bring this machine online.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        stepIndex = index
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: step.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 18)
                            Text(step.title)
                                .font(.callout.weight(index == stepIndex ? .semibold : .regular))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if index < stepIndex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(index == stepIndex ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityIdentifier("setup.step.\(step.rawValue)")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(step.title)
                    .accessibilityIdentifier("setup.step.\(step.rawValue)")
                    .buttonStyle(.plain)
                    .foregroundStyle(index == stepIndex ? .primary : .secondary)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Label(draft.machine.deviceID.isEmpty ? "Device not named" : draft.machine.deviceID, systemImage: "desktopcomputer")
                Label(draft.machine.room.isEmpty ? "Room unset" : draft.machine.room, systemImage: "house")
                Label(draft.roles.isEmpty ? "No roles selected" : roleSummary, systemImage: "dot.radiowaves.left.and.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 230)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(currentStep.title)
                    .font(.title2.weight(.semibold))
                Text(currentStep.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if loaded {
                StatusPill(level: settings.setupCompleted ? .green : .amber, text: settings.setupCompleted ? "Replayable" : "First run")
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .identity:
            identityStep
        case .machine:
            machineStep
        case .roles:
            rolesStep
        case .providers:
            providersStep
        case .roleConfig:
            roleConfigStep
        case .review:
            reviewStep
        case .verify:
            verifyStep
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupHeroLine(icon: "person.badge.shield.checkmark", title: "Create the first admin", detail: "This user becomes the strong identity for this Mac and approves new WhatsApp users.")
            WizardField(title: "Name") {
                TextField("Neil Barton", text: $draft.admin.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.admin.name")
            }
            WizardField(title: "Email") {
                TextField("neil@example.com", text: $draft.admin.email)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.admin.email")
            }
            WizardField(title: "Phone") {
                TextField("+44 7921 815819", text: $draft.admin.phone)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.admin.phone")
            }
            WizardField(title: "WhatsApp admin") {
                TextField("Defaults to phone", text: $draft.admin.whatsappAdmin)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.admin.whatsapp")
            }
        }
    }

    private var machineStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupHeroLine(icon: "macwindow.badge.plus", title: "Name the machine", detail: "Jarvis uses the device name for pairing, profiles, status, and memory boundaries.")
            WizardField(title: "Device name") {
                TextField("office-imac", text: $draft.machine.deviceID)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.machine.device")
            }
            WizardField(title: "Room") {
                TextField("Office", text: $draft.machine.room)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.machine.room")
            }
            Toggle("This is a personal Mac for the admin", isOn: $draft.machine.personal)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("setup.machine.personal")
        }
    }

    private var rolesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupHeroLine(icon: "point.3.connected.trianglepath.dotted", title: "Choose local roles", detail: "Each role becomes a launchd service owned by this Mac.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(JarvisRole.allCases) { role in
                    RoleChoiceCard(role: role, selected: draft.roles.contains(role)) {
                        toggleRole(role)
                    }
                }
            }
        }
    }

    private var providersStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupHeroLine(icon: "key.horizontal", title: "Add provider keys", detail: "Existing keys stay in place. Blank secret fields are preserved when you apply.")
            WizardSecret(title: "OpenAI API key", value: $draft.providers.openAIAPIKey, alreadySet: draft.providers.hasOpenAIAPIKey)
            WizardSecret(title: "OpenRouter API key", value: $draft.providers.openRouterAPIKey, alreadySet: draft.providers.hasOpenRouterAPIKey)
            WizardSecret(title: "Anthropic API key", value: $draft.providers.anthropicAPIKey, alreadySet: draft.providers.hasAnthropicAPIKey)
            WizardSecret(title: "Gemini API key", value: $draft.providers.geminiAPIKey, alreadySet: draft.providers.hasGeminiAPIKey)
            WizardSecret(title: "TTS API key", value: $draft.providers.ttsAPIKey, alreadySet: draft.providers.hasTTSAPIKey)
            WizardSecret(title: "Web search key", value: $draft.providers.toolsWebsearchAPIKey, alreadySet: draft.providers.hasToolsWebsearchAPIKey)
        }
    }

    private var roleConfigStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if draft.roles.contains(.brain) {
                RoleConfigPanel(title: "Brain", icon: "brain.head.profile") {
                    WizardField(title: "Bind host") {
                        TextField("0.0.0.0", text: $draft.brain.host)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.brain.host")
                    }
                    WizardField(title: "Port") {
                        TextField("8700", text: $draft.brain.port)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.brain.port")
                    }
                }
            }
            if draft.roles.contains(.intercom) {
                RoleConfigPanel(title: "Intercom", icon: "waveform") {
                    if draft.roles.contains(.brain) {
                        Label("This intercom will be paired to the local brain automatically.", systemImage: "link.badge.plus")
                            .foregroundStyle(.secondary)
                    } else {
                        WizardField(title: "Brain host") {
                            TextField("imac.private", text: $draft.intercom.brainHost)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("setup.intercom.brain_host")
                        }
                        WizardField(title: "Brain port") {
                            TextField("8700", text: $draft.intercom.brainPort)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("setup.intercom.brain_port")
                        }
                        WizardSecret(title: "Pairing token", value: $draft.intercom.token, alreadySet: draft.intercom.paired)
                    }
                }
            }
            if draft.roles.contains(.worker) {
                RoleConfigPanel(title: "Worker", icon: "hammer") {
                    WizardField(title: "Repo root") {
                        TextField("/Users/neilbarton/Development", text: $draft.worker.repoRoot)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.worker.repo_root")
                    }
                    WizardField(title: "Agent") {
                        Picker("Agent", selection: $draft.worker.agent) {
                            Text("Codex").tag("codex")
                            Text("Claude").tag("claude")
                        }
                        .pickerStyle(.segmented)
                    }
                    WizardField(title: "Shell secret allowlist") {
                        TextField("OPENAI_API_KEY,ANTHROPIC_API_KEY", text: $draft.worker.shellSecrets)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.worker.shell_secrets")
                    }
                    WizardField(title: "Peekaboo providers") {
                        TextField("openai/gpt-5.5", text: $draft.worker.peekabooAIProviders)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.worker.peekaboo_providers")
                    }
                    WizardField(title: "Peekaboo base URL") {
                        TextField("http://localhost:4000/v1", text: $draft.worker.peekabooOpenAIBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.worker.peekaboo_base_url")
                    }
                    WizardSecret(title: "Peekaboo OpenAI key", value: $draft.providers.workerPeekabooOpenAIAPIKey, alreadySet: draft.providers.hasWorkerPeekabooOpenAIAPIKey)
                }
            }
            if draft.roles.contains(.whatsapp) {
                RoleConfigPanel(title: "WhatsApp", icon: "message") {
                    WizardField(title: "Admin number") {
                        TextField("Defaults to admin phone", text: $draft.whatsapp.admin)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.whatsapp.admin")
                    }
                    WizardField(title: "Account") {
                        TextField("Optional wacli account", text: $draft.whatsapp.account)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("setup.whatsapp.account")
                    }
                    Button {
                        Task { await runWhatsAppAuth() }
                    } label: {
                        Label("Link WhatsApp", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isApplying)
                    .accessibilityIdentifier("setup.whatsapp.link")
                    if let whatsappAuthResult {
                        PairingOutputBlock(text: [whatsappAuthResult.stdout, whatsappAuthResult.stderr].filter { !$0.isEmpty }.joined(separator: "\n"))
                    }
                }
            }
            if draft.roles.isEmpty {
                SetupHeroLine(icon: "exclamationmark.triangle", title: "No roles selected", detail: "Choose at least one role before configuring services.")
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupHeroLine(icon: "checklist.checked", title: "Review changes", detail: "Applying merges with existing config and preserves blank secret fields.")
            ReviewGrid(items: [
                ("Admin", draft.admin.name.isEmpty ? "Not set" : draft.admin.name),
                ("Device", draft.machine.deviceID),
                ("Room", draft.machine.room),
                ("Roles", roleSummary),
                ("Identity", draft.machine.personal ? "Personal" : "Shared house"),
                ("WhatsApp", draft.roles.contains(.whatsapp) ? "Pairing policy" : "Not installed")
            ])
            if let applyResult {
                PairingOutputBlock(text: "Updated \(applyResult.envFile)\nUser file: \(applyResult.userFile)\nChanged: \(applyResult.changedKeys.joined(separator: ", "))")
            }
        }
    }

    private var verifyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupHeroLine(icon: "waveform.path.ecg.rectangle", title: "Verify services", detail: "Jarvis checks config, pairing, selected services, and external tools where possible.")
            if let validation {
                ValidationBlock(validation: validation)
            } else {
                Text("Apply setup to run validation.")
                    .foregroundStyle(.secondary)
            }
            if !viewModel.lastCommandOutput.isEmpty {
                PairingOutputBlock(text: viewModel.lastCommandOutput)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .accessibilityIdentifier("setup.error")
            } else if !statusText.isEmpty {
                Label(statusText, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("setup.status")
            }
            Spacer()
            Button("Back") {
                stepIndex = max(0, stepIndex - 1)
            }
            .disabled(stepIndex == 0 || isApplying)
            .accessibilityIdentifier("setup.back")
            if stepIndex == steps.count - 1 {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .accessibilityIdentifier("setup.close.label")
                }
                .disabled(isApplying)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Close")
                .accessibilityIdentifier("setup.close")
            } else {
                Button {
                    stepIndex = min(steps.count - 1, stepIndex + 1)
                } label: {
                    Text("Next")
                        .accessibilityIdentifier("setup.next.label")
                }
                .disabled(isApplying)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Next")
                .accessibilityIdentifier("setup.next")
            }
            Button {
                Task { await applySetup() }
            } label: {
                if isApplying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Apply", systemImage: "square.and.arrow.down")
                        .accessibilityIdentifier("setup.apply.label")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplying || draft.roles.isEmpty)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Apply")
            .accessibilityIdentifier("setup.apply")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var uiTestControlsEnabled: Bool {
        ProcessInfo.processInfo.environment["JARVIS_APP_UI_TEST_MODE"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--jarvis-ui-test-mode")
            || Bundle.main.bundleIdentifier == "dev.infinitestack.jarvis.mac.uitesthost"
    }

    private var uiTestState: String {
        if isApplying {
            return "applying"
        }
        if errorText != nil {
            return "error"
        }
        if validation != nil {
            return "validated"
        }
        return "idle"
    }

    private var uiTestControlStrip: some View {
        HStack(spacing: 8) {
            TextField("UI command", text: $uiTestCommand)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
                .accessibilityIdentifier("setup.test.command")
                .onChange(of: uiTestCommand) { _, newValue in
                    handleUITestCommand(newValue)
                }
            TextField("UI state", text: .constant(uiTestState))
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .accessibilityIdentifier("setup.test.state")
            TextField("UI error", text: .constant(errorText ?? ""))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("setup.test.error")
            TextField("UI completed", text: .constant(settings.setupCompleted ? "true" : "false"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .accessibilityIdentifier("setup.test.completed")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
    }

    private func handleUITestCommand(_ rawValue: String) {
        let command = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["back", "next", "brain", "intercom", "worker", "whatsapp", "apply"].contains(command) else {
            return
        }
        switch command {
        case "back":
            stepIndex = max(0, stepIndex - 1)
        case "next":
            stepIndex = min(steps.count - 1, stepIndex + 1)
        case "brain":
            toggleRole(.brain)
        case "intercom":
            toggleRole(.intercom)
        case "worker":
            toggleRole(.worker)
        case "whatsapp":
            toggleRole(.whatsapp)
        case "apply":
            Task { await applySetup() }
        default:
            break
        }
        DispatchQueue.main.async {
            uiTestCommand = ""
        }
    }

    private func toggleRole(_ role: JarvisRole) {
        if draft.roles.contains(role) {
            draft.roles.remove(role)
        } else {
            draft.roles.insert(role)
            if role == .whatsapp {
                draft.whatsapp.enabled = true
            }
        }
    }

    private var currentStep: SetupWizardStep {
        steps[min(max(stepIndex, 0), steps.count - 1)]
    }

    private var roleSummary: String {
        JarvisClient.orderedInstalledRoles(for: draft.roles).map(\.title).joined(separator: ", ")
    }

    private func loadExistingSetup() async {
        guard !loaded else { return }
        loaded = true
        stepIndex = min(max(settings.setupLastStep, 0), steps.count - 1)
        do {
            var existing = try await JarvisClient(configuration: settings.configuration).setupRead()
            if existing.roles.isEmpty {
                existing.roles = settings.installedRoles
            }
            if existing.admin.whatsappAdmin.isEmpty {
                existing.admin.whatsappAdmin = existing.admin.phone
            }
            if existing.whatsapp.admin.isEmpty {
                existing.whatsapp.admin = existing.admin.whatsappAdmin
            }
            draft = existing
            statusText = "Loaded current setup."
        } catch {
            statusText = "Starting a new setup."
        }
    }

    private func applySetup() async {
        isApplying = true
        errorText = nil
        statusText = "Writing configuration."
        if draft.admin.whatsappAdmin.isEmpty {
            draft.admin.whatsappAdmin = draft.admin.phone
        }
        if draft.whatsapp.admin.isEmpty {
            draft.whatsapp.admin = draft.admin.whatsappAdmin
        }
        if draft.roles.contains(.whatsapp) {
            draft.whatsapp.enabled = true
        }
        let client = JarvisClient(configuration: settings.configuration)
        do {
            applyResult = try await client.setupApply(draft)
            settings.installedRoles = draft.roles
            settings.pairingBrainHost = draft.roles.contains(.brain) ? "localhost" : draft.intercom.brainHost
            statusText = "Installing selected services."
            let servicesInstalled = await viewModel.installSelectedServices()
            guard servicesInstalled else {
                throw SetupWizardError.serviceInstallFailed(
                    viewModel.lastError ?? "Check the command output for details."
                )
            }
            statusText = "Validating setup."
            validation = try await client.setupValidate(roles: draft.roles)
            await viewModel.refresh(includeDocker: true)
            settings.markSetupCompleted(step: steps.count - 1)
            stepIndex = steps.count - 1
            statusText = "Setup applied."
        } catch {
            errorText = readable(error)
        }
        isApplying = false
    }

    private func runWhatsAppAuth() async {
        isApplying = true
        errorText = nil
        statusText = "Waiting for WhatsApp QR scan."
        do {
            whatsappAuthResult = try await JarvisClient(configuration: settings.configuration)
                .whatsappAuth(account: draft.whatsapp.account)
            statusText = whatsappAuthResult?.ok == true ? "WhatsApp linked." : "WhatsApp auth needs attention."
        } catch {
            errorText = readable(error)
        }
        isApplying = false
    }

    private func readable(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

enum SetupWizardError: LocalizedError {
    case serviceInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .serviceInstallFailed(let message):
            "Service installation failed.\n\(message)"
        }
    }
}

enum SetupWizardStep: String, CaseIterable {
    case identity
    case machine
    case roles
    case providers
    case roleConfig
    case review
    case verify

    var title: String {
        switch self {
        case .identity: "Admin"
        case .machine: "Machine"
        case .roles: "Roles"
        case .providers: "Keys"
        case .roleConfig: "Services"
        case .review: "Review"
        case .verify: "Verify"
        }
    }

    var subtitle: String {
        switch self {
        case .identity: "Set the first trusted user."
        case .machine: "Name the physical place this Jarvis belongs to."
        case .roles: "Decide what runs on this Mac."
        case .providers: "Connect the services Jarvis uses."
        case .roleConfig: "Tune each selected role."
        case .review: "Check the exact setup before applying."
        case .verify: "Confirm the machine is ready."
        }
    }

    var symbolName: String {
        switch self {
        case .identity: "person.crop.circle.badge.checkmark"
        case .machine: "desktopcomputer"
        case .roles: "square.stack.3d.up"
        case .providers: "key"
        case .roleConfig: "slider.horizontal.3"
        case .review: "checklist"
        case .verify: "checkmark.seal"
        }
    }
}

struct SetupHeroLine: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WizardField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 0) {
            GridRow {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 160, alignment: .leading)
                content
            }
        }
    }
}

struct WizardSecret: View {
    let title: String
    @Binding var value: String
    let alreadySet: Bool

    var body: some View {
        WizardField(title: title) {
            HStack(spacing: 8) {
                SecureField(alreadySet ? "Already set; leave blank to keep" : "Paste key", text: $value)
                    .textFieldStyle(.roundedBorder)
                if alreadySet {
                    Label("Set", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

struct RoleChoiceCard: View {
    let role: JarvisRole
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selected ? .white : Color.accentColor)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? .white : .secondary)
                }
                Text(role.title)
                    .font(.headline)
                    .foregroundStyle(selected ? .white : .primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(selected ? .white.opacity(0.82) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(minHeight: 128, alignment: .topLeading)
            .background(selected ? roleColor : Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.clear : Color.secondary.opacity(0.18)))
            .accessibilityIdentifier("setup.role.\(role.rawValue).content")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(role.title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .buttonStyle(.plain)
        .accessibilityIdentifier("setup.role.\(role.rawValue)")
    }

    private var roleColor: Color {
        switch role {
        case .brain: .indigo
        case .intercom: .teal
        case .worker: .orange
        case .whatsapp: .green
        }
    }

    private var symbol: String {
        switch role {
        case .brain: "brain.head.profile"
        case .intercom: "waveform"
        case .worker: "hammer"
        case .whatsapp: "message"
        }
    }

    private var detail: String {
        switch role {
        case .brain: "Central reasoning, memory, gateway, and pairing authority."
        case .intercom: "Wake word, microphone, speaker, and local voice edge."
        case .worker: "Coding jobs, shell, browser, and GUI control on this Mac."
        case .whatsapp: "Text channel with admin-approved user onboarding."
        }
    }
}

struct RoleConfigPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
        .padding(16)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15)))
    }
}

struct ReviewGrid: View {
    let items: [(String, String)]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            ForEach(items, id: \.0) { item in
                GridRow {
                    Text(item.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.1.isEmpty ? "Not set" : item.1)
                        .font(.callout)
                }
            }
        }
    }
}

struct ValidationBlock: View {
    let validation: SetupValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(validation.ok ? "Configuration is ready" : "Configuration needs attention", systemImage: validation.ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(validation.ok ? .green : .orange)
                .font(.headline)
                .accessibilityIdentifier("setup.validation.summary")
            if !validation.missing.isEmpty {
                Text("Missing: \(validation.missing.joined(separator: ", "))")
                    .foregroundStyle(.orange)
            }
            if !validation.warnings.isEmpty {
                Text("Warnings: \(validation.warnings.joined(separator: ", "))")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
