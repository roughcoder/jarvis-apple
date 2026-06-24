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
    @State private var phoneCountry = PhoneCountry.defaultCountry
    @State private var whatsappCountry = PhoneCountry.defaultCountry
    @State private var brainSetupMode: BrainSetupMode = .create

    private var steps: [SetupWizardStep] {
        var values: [SetupWizardStep] = [.brainIntro]
        if draft.roles.contains(.brain) {
            values.append(.identity)
        }
        values.append(.machine)
        if draft.roles.contains(.brain) {
            values.append(.brainConfig)
            values.append(.aiProviders)
        } else if brainSetupMode == .link {
            values.append(.brainLink)
        }
        values.append(.whatsappIntro)
        if draft.roles.contains(.whatsapp) {
            values.append(.whatsappConfig)
        }
        values.append(.intercomIntro)
        if draft.roles.contains(.intercom) {
            values.append(.voiceProviders)
        }
        values.append(.workerIntro)
        if draft.roles.contains(.worker) {
            values.append(.workerConfig)
        }
        values.append(.review)
        values.append(.verify)
        return values
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if uiTestControlsEnabled {
                        uiTestControlStrip
                    }
                    stepContent
                        .padding(34)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 860, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("setup.wizard")
        .task {
            await loadExistingSetup()
        }
        .onChange(of: stepIndex) { _, newValue in
            settings.rememberSetupStep(newValue)
        }
        .onChange(of: draft.roles) {
            clampStepIndex()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 10) {
                    Image(systemName: currentStep.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Jarvis Setup")
                        .font(.callout.weight(.semibold))
                    Text("Step \(stepIndex + 1) of \(steps.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if loaded {
                        StatusPill(level: settings.setupCompleted ? .green : .amber, text: settings.setupCompleted ? "Replayable" : "First run")
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    navigationControls
                }
                Text(currentStep.title)
                    .font(.title2.weight(.semibold))
                Text(currentStep.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
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
            ProgressView(value: Double(stepIndex + 1), total: Double(max(steps.count, 1)))
                .progressViewStyle(.linear)
                .accessibilityIdentifier("setup.progress")
                .accessibilityLabel("Setup progress")
                .accessibilityValue("Step \(stepIndex + 1) of \(steps.count)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .brainIntro:
            brainIntroStep
        case .brainLink:
            brainLinkStep
        case .identity:
            identityStep
        case .machine:
            machineStep
        case .brainConfig:
            brainConfigStep
        case .aiProviders:
            aiProvidersStep
        case .whatsappIntro:
            whatsappIntroStep
        case .whatsappConfig:
            whatsappConfigStep
        case .intercomIntro:
            intercomIntroStep
        case .voiceProviders:
            voiceProvidersStep
        case .workerIntro:
            workerIntroStep
        case .workerConfig:
            workerConfigStep
        case .review:
            reviewStep
        case .verify:
            verifyStep
        }
    }

    private var identityStep: some View {
        WizardSection(
            icon: "person.badge.shield.checkmark",
            title: "Create the first trusted person",
            detail: "Jarvis uses this identity for approval, memory, and personal-device permissions. Keep it accurate; you can replay setup later."
        ) {
            WizardField(title: "Name", description: "Shown in the local user file and used as the default Jarvis identity.") {
                TextField("Neil Barton", text: $draft.admin.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.admin.name")
            }
            WizardField(title: "Email", description: "Stored as a local fact so Jarvis can identify the admin without asking again.") {
                TextField("neil@example.com", text: $draft.admin.email)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.admin.email")
            }
            WizardField(title: "Phone", description: "Choose the country once, then type the local number naturally. A leading 0 is removed when saved.") {
                CountryPhoneField(country: $phoneCountry, number: $draft.admin.phone, identifier: "setup.admin.phone")
            }
            WizardField(title: "WhatsApp admin", description: "Defaults to the same number. Override only if approvals should go to another phone.") {
                CountryPhoneField(country: $whatsappCountry, number: $draft.admin.whatsappAdmin, identifier: "setup.admin.whatsapp")
            }
        }
    }

    private var machineStep: some View {
        WizardSection(
            icon: "macwindow.badge.plus",
            title: "Place this Mac in the house",
            detail: "This becomes the stable identity for pairing, service status, and memory boundaries."
        ) {
            WizardField(title: "Device name", description: "A short machine id. It appears in Brain device pairing and fleet status.") {
                TextField("office-imac", text: $draft.machine.deviceID)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.machine.device")
            }
            WizardField(title: "Room", description: "Used by the Brain and gateway so events are grounded in a physical location.") {
                TextField("Office", text: $draft.machine.room)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.machine.room")
            }
            WizardField(title: "Ownership", description: "Personal Macs get the admin identity. Shared machines stay scoped to the house.") {
                Picker("Ownership", selection: $draft.machine.personal) {
                    Text("Personal").tag(true)
                    Text("Shared").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("setup.machine.personal")
            }
        }
    }

    private var brainIntroStep: some View {
        WizardSection(
            icon: "brain.head.profile",
            title: "Create a Brain or link to one?",
            detail: "The Brain owns trusted users, memory, device pairing, and model routing. Create it once on the main machine; link other Macs to that Brain."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                BrainModeButton(
                    title: "Create Brain on this Mac",
                    detail: "Use this for the main always-on Mac. Setup will create the local admin identity and provider routes.",
                    icon: "plus.circle.fill",
                    selected: brainSetupMode == .create,
                    identifier: "setup.brain.create"
                ) {
                    brainSetupMode = .create
                    setRole(.brain, enabled: true)
                    goForward()
                }
                BrainModeButton(
                    title: "Link to an existing Brain",
                    detail: "Use this for laptops, worker Macs, or intercom machines. Trusted users stay on the Brain.",
                    icon: "link.circle",
                    selected: brainSetupMode == .link,
                    identifier: "setup.brain.link"
                ) {
                    brainSetupMode = .link
                    setRole(.brain, enabled: false)
                    goForward()
                }
                BrainModeButton(
                    title: "Decide later",
                    detail: "Skip Brain setup for now. You can still replay setup from the menu bar.",
                    icon: "clock",
                    selected: brainSetupMode == .skip,
                    identifier: "setup.brain.skip"
                ) {
                    brainSetupMode = .skip
                    setRole(.brain, enabled: false)
                    goForward()
                }
            }
        }
    }

    private var brainLinkStep: some View {
        WizardSection(
            icon: "link",
            title: "Existing Brain connection",
            detail: "Enter the Brain this Mac should use. These values prefill intercom and worker pairing when those capabilities are enabled."
        ) {
            WizardField(title: "Brain host", description: "The hostname or IP of the Mac running the Brain.") {
                TextField("imac.private", text: $draft.intercom.brainHost)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.brain.link_host")
            }
            WizardField(title: "Brain port", description: "Usually 8700 unless the Brain was configured differently.") {
                TextField("8700", text: $draft.intercom.brainPort)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.brain.link_port")
            }
            WizardSecret(title: "Pairing token", description: "Paste the token generated by the Brain. You can leave it blank if you will pair manually later.", value: $draft.intercom.token, alreadySet: draft.intercom.paired)
        }
    }

    private var brainConfigStep: some View {
        WizardSection(
            icon: "server.rack",
            title: "Brain service",
            detail: "These defaults make the Brain reachable by local intercoms and workers. Keep localhost-only only when this Mac is not the central Brain."
        ) {
            WizardField(title: "Bind host", description: "Use 0.0.0.0 when other devices on your network should pair to this Brain.") {
                TextField("0.0.0.0", text: $draft.brain.host)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.brain.host")
            }
            WizardField(title: "Port", description: "The Brain websocket/API port used by intercoms, workers, and WhatsApp.") {
                TextField("8700", text: $draft.brain.port)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.brain.port")
            }
        }
    }

    private var aiProvidersStep: some View {
        WizardSection(
            icon: "sparkles",
            title: "AI providers",
            detail: "Add the providers Jarvis can route through. Pick the primary provider now; leave keys blank to preserve existing values."
        ) {
            WizardField(title: "Primary AI provider", description: "Jarvis uses this first for reasoning unless a role chooses another configured provider.") {
                Picker("Primary AI provider", selection: $draft.providers.aiProvider) {
                    Text("OpenAI").tag("openai")
                    Text("Anthropic").tag("anthropic")
                    Text("OpenRouter").tag("openrouter")
                    Text("Gemini").tag("gemini")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("setup.providers.ai")
            }
            WizardField(title: "Default model", description: "Model options adapt to the selected provider.") {
                Picker("Default model", selection: $draft.providers.aiModel) {
                    ForEach(models(for: draft.providers.aiProvider), id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .accessibilityIdentifier("setup.providers.ai_model")
            }
            providerKeyFields
            WizardField(title: "Web search", description: "Choose the search provider used when Jarvis needs live web context.") {
                Picker("Web search", selection: $draft.providers.webSearchProvider) {
                    Text("Tavily").tag("tavily")
                    Text("Brave").tag("brave")
                    Text("SerpAPI").tag("serpapi")
                    Text("Skip for now").tag("none")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("setup.providers.web_search")
            }
            if draft.providers.webSearchProvider != "none" {
                WizardSecret(title: "\(providerTitle(draft.providers.webSearchProvider)) key", description: "Stored in ~/.jarvis/.env and redacted in app output.", value: $draft.providers.toolsWebsearchAPIKey, alreadySet: draft.providers.hasToolsWebsearchAPIKey)
            }
        }
    }

    @ViewBuilder
    private var providerKeyFields: some View {
        switch draft.providers.aiProvider {
        case "anthropic":
            WizardSecret(title: "Anthropic API key", description: "Used for Claude models and Brain reasoning routes.", value: $draft.providers.anthropicAPIKey, alreadySet: draft.providers.hasAnthropicAPIKey)
        case "openrouter":
            WizardSecret(title: "OpenRouter API key", description: "Used for routed models across multiple providers.", value: $draft.providers.openRouterAPIKey, alreadySet: draft.providers.hasOpenRouterAPIKey)
        case "gemini":
            WizardSecret(title: "Gemini API key", description: "Used for Gemini models and compatible reasoning routes.", value: $draft.providers.geminiAPIKey, alreadySet: draft.providers.hasGeminiAPIKey)
        default:
            WizardSecret(title: "OpenAI API key", description: "Used for OpenAI models and compatible local tooling.", value: $draft.providers.openAIAPIKey, alreadySet: draft.providers.hasOpenAIAPIKey)
        }
    }

    private var whatsappIntroStep: some View {
        CapabilityDecisionStep(
            icon: "message.badge",
            title: "Enable WhatsApp on this Mac?",
            detail: "WhatsApp gives Jarvis a text channel with admin approval. Setup will check the local account state and can show the QR flow when linking is needed.",
            enabled: draft.roles.contains(.whatsapp),
            enableTitle: "Enable WhatsApp",
            skipTitle: "Skip WhatsApp"
        ) {
            setRole(.whatsapp, enabled: true)
            goForward()
        } skip: {
            setRole(.whatsapp, enabled: false)
            goForward()
        }
    }

    private var whatsappConfigStep: some View {
        WizardSection(
            icon: "qrcode.viewfinder",
            title: "WhatsApp account",
            detail: "If wacli is already authenticated, this step can stay as-is. If not, link the account and scan the QR code."
        ) {
            WizardField(title: "Admin number", description: "This number approves new WhatsApp users. A leading 0 is removed when saved.") {
                CountryPhoneField(country: $whatsappCountry, number: $draft.whatsapp.admin, identifier: "setup.whatsapp.admin")
            }
            WizardField(title: "Account", description: "Optional named wacli account when you manage more than one WhatsApp session.") {
                TextField("Default account", text: $draft.whatsapp.account)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.whatsapp.account")
            }
            HStack(spacing: 10) {
                Button {
                    Task { await runWhatsAppAuth() }
                } label: {
                    Label(whatsappAuthResult?.ok == true ? "Linked" : "Check or Link WhatsApp", systemImage: whatsappAuthResult?.ok == true ? "checkmark.circle" : "qrcode.viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApplying)
                .accessibilityIdentifier("setup.whatsapp.link")
                Text(whatsappAuthResult == nil ? "This checks the current auth state before asking you to scan." : (whatsappAuthResult?.ok == true ? "WhatsApp is linked." : "Scan the QR or review the message below."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let whatsappAuthResult {
                PairingOutputBlock(text: [whatsappAuthResult.stdout, whatsappAuthResult.stderr].filter { !$0.isEmpty }.joined(separator: "\n"))
            }
        }
    }

    private var intercomIntroStep: some View {
        CapabilityDecisionStep(
            icon: "waveform.badge.mic",
            title: "Enable voice intercom?",
            detail: "The intercom is the microphone, speaker, wake-word, speech-to-text, and text-to-speech edge for this Mac.",
            enabled: draft.roles.contains(.intercom),
            enableTitle: "Enable Intercom",
            skipTitle: "Skip Voice"
        ) {
            setRole(.intercom, enabled: true)
            goForward()
        } skip: {
            setRole(.intercom, enabled: false)
            goForward()
        }
    }

    private var voiceProvidersStep: some View {
        WizardSection(
            icon: "waveform.and.mic",
            title: "Voice providers",
            detail: "Choose how Jarvis listens and speaks on this Mac. Local STT avoids an API key; cloud providers can improve quality."
        ) {
            if draft.roles.contains(.brain) {
                StatusNote(icon: "link.badge.plus", text: "This intercom will auto-pair to the Brain on this Mac.")
            } else {
                WizardField(title: "Brain host", description: "The Brain this intercom should connect to.") {
                    TextField("imac.private", text: $draft.intercom.brainHost)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("setup.intercom.brain_host")
                }
                WizardField(title: "Brain port", description: "Usually 8700 unless your Brain uses a custom port.") {
                    TextField("8700", text: $draft.intercom.brainPort)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("setup.intercom.brain_port")
                }
                WizardSecret(title: "Pairing token", description: "Generated on the Brain. Leave blank only if you will pair later.", value: $draft.intercom.token, alreadySet: draft.intercom.paired)
            }
            WizardField(title: "Speech to text", description: "Select the listener provider. Local is the least setup; hosted providers may need keys.") {
                Picker("Speech to text", selection: $draft.providers.sttProvider) {
                    Text("Local Whisper").tag("local")
                    Text("OpenAI").tag("openai")
                    Text("Deepgram").tag("deepgram")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("setup.providers.stt")
            }
            if draft.providers.sttProvider == "openai" {
                WizardSecret(title: "OpenAI key", description: "Reuses the OpenAI provider key when available.", value: $draft.providers.openAIAPIKey, alreadySet: draft.providers.hasOpenAIAPIKey)
            }
            WizardField(title: "Text to speech", description: "Select the voice provider for spoken replies.") {
                Picker("Text to speech", selection: $draft.providers.ttsProvider) {
                    Text("Inworld").tag("inworld")
                    Text("OpenAI").tag("openai")
                    Text("ElevenLabs").tag("elevenlabs")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("setup.providers.tts")
            }
            WizardSecret(title: "\(providerTitle(draft.providers.ttsProvider)) voice key", description: "Stored locally and used only by the voice service.", value: $draft.providers.ttsAPIKey, alreadySet: draft.providers.hasTTSAPIKey)
        }
    }

    private var workerIntroStep: some View {
        CapabilityDecisionStep(
            icon: "hammer.circle",
            title: "Enable worker automation?",
            detail: "The worker builds projects, runs coding jobs, uses a browser, and can control this Mac when you allow it.",
            enabled: draft.roles.contains(.worker),
            enableTitle: "Enable Worker",
            skipTitle: "Skip Worker"
        ) {
            setRole(.worker, enabled: true)
            goForward()
        } skip: {
            setRole(.worker, enabled: false)
            goForward()
        }
    }

    private var workerConfigStep: some View {
        WizardSection(
            icon: "desktopcomputer.and.arrow.down",
            title: "Worker workspace",
            detail: "This is where Jarvis will build projects, create worktrees, run agents, and keep job output."
        ) {
            WizardField(title: "Projects folder", description: "The root folder where coding projects live and new builds should be created.") {
                TextField("/Users/neilbarton/Development", text: $draft.worker.repoRoot)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.worker.repo_root")
            }
            WizardField(title: "Default agent", description: "The coding agent the worker should start with for jobs from the Brain.") {
                Picker("Agent", selection: $draft.worker.agent) {
                    Text("Codex").tag("codex")
                    Text("Claude").tag("claude")
                }
                .pickerStyle(.segmented)
            }
            WizardField(title: "Shell secrets", description: "Comma-separated environment variable names the worker may pass to shell jobs.") {
                TextField("OPENAI_API_KEY,ANTHROPIC_API_KEY", text: $draft.worker.shellSecrets)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("setup.worker.shell_secrets")
            }
            WizardField(title: "Mac control provider", description: "Choose the AI provider used when Jarvis needs to inspect or control the Mac UI.") {
                Picker("Mac control provider", selection: $draft.providers.macControlProvider) {
                    ForEach(configuredAIProviders, id: \.self) { provider in
                        Text(providerTitle(provider)).tag(provider)
                    }
                }
                .accessibilityIdentifier("setup.worker.mac_control_provider")
            }
            WizardField(title: "Mac control model", description: "Model choices are limited to the selected provider.") {
                Picker("Mac control model", selection: $draft.providers.macControlModel) {
                    ForEach(models(for: draft.providers.macControlProvider), id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .accessibilityIdentifier("setup.worker.mac_control_model")
            }
            macControlKeyField
        }
    }

    @ViewBuilder
    private var macControlKeyField: some View {
        switch draft.providers.macControlProvider {
        case "openrouter":
            WizardSecret(title: "OpenRouter key for Mac control", description: "Used by the GUI-control provider when this capability is enabled.", value: $draft.providers.workerPeekabooOpenRouterAPIKey, alreadySet: draft.providers.hasWorkerPeekabooOpenRouterAPIKey)
        default:
            WizardSecret(title: "OpenAI key for Mac control", description: "Used by the GUI-control provider when this capability is enabled.", value: $draft.providers.workerPeekabooOpenAIAPIKey, alreadySet: draft.providers.hasWorkerPeekabooOpenAIAPIKey)
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

    private var navigationControls: some View {
        HStack(spacing: 10) {
            Button("Back") {
                goBack()
            }
            .disabled(stepIndex == 0 || isApplying)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("setup.back")
            if stepIndex == steps.count - 1 {
                Button("Close") {
                    requestClose()
                }
                .disabled(isApplying)
                .accessibilityLabel("Close")
                .accessibilityIdentifier("setup.close")
            } else {
                Button("Next") {
                    goForward()
                }
                .disabled(isApplying || !canAdvance)
                .accessibilityLabel("Next")
                .accessibilityIdentifier("setup.next")
            }
            Button(action: {
                Task { await applySetup() }
            }) {
                if isApplying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Apply", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplying || !canApply)
            .accessibilityLabel("Apply")
            .accessibilityIdentifier("setup.apply")
        }
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
        guard ["back", "next", "review", "brain", "intercom", "worker", "whatsapp", "apply"].contains(command) else {
            return
        }
        switch command {
        case "back":
            goBack()
        case "next":
            goForward()
        case "review":
            stepIndex = steps.firstIndex(of: .review) ?? max(0, steps.count - 2)
        case "brain":
            brainSetupMode = .create
            setRole(.brain, enabled: true)
            goForward()
        case "intercom":
            setRole(.intercom, enabled: true)
        case "worker":
            setRole(.worker, enabled: true)
        case "whatsapp":
            setRole(.whatsapp, enabled: true)
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
        setRole(role, enabled: !draft.roles.contains(role))
    }

    private func setRole(_ role: JarvisRole, enabled: Bool) {
        if enabled {
            draft.roles.insert(role)
        } else {
            draft.roles.remove(role)
        }
        if role == .whatsapp {
            draft.whatsapp.enabled = enabled
        }
        clampStepIndex()
    }

    private var currentStep: SetupWizardStep {
        steps[min(max(stepIndex, 0), steps.count - 1)]
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .identity:
            !draft.admin.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .machine:
            !draft.machine.deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !draft.machine.room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .brainLink:
            !draft.intercom.brainHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            true
        }
    }

    private var canApply: Bool {
        currentStep == .review && !draft.roles.isEmpty && canAdvance
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
            if existing.roles.contains(.brain) {
                brainSetupMode = .create
            } else if !existing.intercom.brainHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                brainSetupMode = .link
            } else {
                brainSetupMode = .skip
            }
            phoneCountry = PhoneCountry.country(matching: existing.admin.phone) ?? .defaultCountry
            whatsappCountry = PhoneCountry.country(matching: existing.admin.whatsappAdmin.isEmpty ? existing.whatsapp.admin : existing.admin.whatsappAdmin) ?? phoneCountry
            draft.admin.phone = PhoneCountry.localNumber(from: existing.admin.phone, country: phoneCountry)
            draft.admin.whatsappAdmin = PhoneCountry.localNumber(from: existing.admin.whatsappAdmin, country: whatsappCountry)
            draft.whatsapp.admin = PhoneCountry.localNumber(from: existing.whatsapp.admin, country: whatsappCountry)
            statusText = "Loaded current setup."
        } catch {
            statusText = "Starting a new setup."
        }
    }

    private func applySetup() async {
        isApplying = true
        errorText = nil
        statusText = "Writing configuration."
        var payload = draft
        if payload.admin.whatsappAdmin.isEmpty {
            payload.admin.whatsappAdmin = payload.admin.phone
        }
        if payload.whatsapp.admin.isEmpty {
            payload.whatsapp.admin = payload.admin.whatsappAdmin
        }
        payload.admin.phone = phoneCountry.normalized(payload.admin.phone)
        payload.admin.whatsappAdmin = whatsappCountry.normalized(payload.admin.whatsappAdmin)
        payload.whatsapp.admin = whatsappCountry.normalized(payload.whatsapp.admin)
        payload.worker.peekabooAIProviders = payload.providers.macControlProvider
        payload.worker.peekabooAgentModel = payload.providers.macControlModel
        if payload.roles.contains(.whatsapp) {
            payload.whatsapp.enabled = true
        }
        let client = JarvisClient(configuration: settings.configuration)
        do {
            applyResult = try await client.setupApply(payload)
            settings.installedRoles = payload.roles
            settings.pairingBrainHost = payload.roles.contains(.brain) ? "localhost" : payload.intercom.brainHost
            statusText = "Installing selected services."
            let servicesInstalled = await viewModel.installSelectedServices()
            guard servicesInstalled else {
                throw SetupWizardError.serviceInstallFailed(
                    viewModel.lastError ?? "Check the command output for details."
                )
            }
            statusText = "Validating setup."
            validation = try await client.setupValidate(roles: payload.roles)
            await viewModel.refresh(includeDocker: true)
            settings.markSetupCompleted(step: steps.count - 1)
            stepIndex = steps.count - 1
            draft = payload
            phoneCountry = PhoneCountry.country(matching: draft.admin.phone) ?? phoneCountry
            whatsappCountry = PhoneCountry.country(matching: draft.admin.whatsappAdmin) ?? whatsappCountry
            draft.admin.phone = PhoneCountry.localNumber(from: draft.admin.phone, country: phoneCountry)
            draft.admin.whatsappAdmin = PhoneCountry.localNumber(from: draft.admin.whatsappAdmin, country: whatsappCountry)
            draft.whatsapp.admin = PhoneCountry.localNumber(from: draft.whatsapp.admin, country: whatsappCountry)
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

    private func goForward() {
        stepIndex = min(steps.count - 1, stepIndex + 1)
    }

    private func goBack() {
        stepIndex = max(0, stepIndex - 1)
    }

    private func clampStepIndex() {
        stepIndex = min(max(stepIndex, 0), steps.count - 1)
    }

    private func requestClose() {
        guard !settings.setupCompleted else {
            dismiss()
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close setup without applying?"
        alert.informativeText = "Jarvis will keep reopening setup until this Mac has been configured."
        alert.addButton(withTitle: "Keep Setup Open")
        alert.addButton(withTitle: "Close Anyway")
        if alert.runModal() == .alertSecondButtonReturn {
            dismiss()
        }
    }

    private var configuredAIProviders: [String] {
        var providers: [String] = []
        if draft.providers.hasOpenAIAPIKey || !draft.providers.openAIAPIKey.isEmpty || draft.providers.aiProvider == "openai" {
            providers.append("openai")
        }
        if draft.providers.hasAnthropicAPIKey || !draft.providers.anthropicAPIKey.isEmpty || draft.providers.aiProvider == "anthropic" {
            providers.append("anthropic")
        }
        if draft.providers.hasOpenRouterAPIKey || !draft.providers.openRouterAPIKey.isEmpty || draft.providers.aiProvider == "openrouter" {
            providers.append("openrouter")
        }
        if draft.providers.hasGeminiAPIKey || !draft.providers.geminiAPIKey.isEmpty || draft.providers.aiProvider == "gemini" {
            providers.append("gemini")
        }
        return providers.isEmpty ? ["openai"] : providers
    }

    private func providerTitle(_ provider: String) -> String {
        switch provider {
        case "anthropic": "Anthropic"
        case "openrouter": "OpenRouter"
        case "gemini": "Gemini"
        case "deepgram": "Deepgram"
        case "elevenlabs": "ElevenLabs"
        case "inworld": "Inworld"
        case "brave": "Brave"
        case "serpapi": "SerpAPI"
        case "tavily": "Tavily"
        case "local": "Local"
        default: "OpenAI"
        }
    }

    private func models(for provider: String) -> [String] {
        switch provider {
        case "anthropic": ["claude-sonnet-4.5", "claude-opus-4.1", "claude-haiku-4.5"]
        case "openrouter": ["openai/gpt-5.5", "anthropic/claude-sonnet-4.5", "google/gemini-2.5-pro"]
        case "gemini": ["gemini-2.5-pro", "gemini-2.5-flash"]
        default: ["gpt-5.5", "gpt-5.3-codex", "gpt-4.1"]
        }
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

enum BrainSetupMode {
    case create
    case link
    case skip
}

enum SetupWizardStep: String, CaseIterable {
    case identity
    case machine
    case brainIntro
    case brainLink
    case brainConfig
    case aiProviders
    case whatsappIntro
    case whatsappConfig
    case intercomIntro
    case voiceProviders
    case workerIntro
    case workerConfig
    case review
    case verify

    var title: String {
        switch self {
        case .identity: "Admin"
        case .machine: "Machine"
        case .brainIntro: "Brain"
        case .brainLink: "Link Brain"
        case .brainConfig: "Brain Service"
        case .aiProviders: "AI"
        case .whatsappIntro: "WhatsApp"
        case .whatsappConfig: "WhatsApp Link"
        case .intercomIntro: "Voice"
        case .voiceProviders: "Speech"
        case .workerIntro: "Worker"
        case .workerConfig: "Workspace"
        case .review: "Review"
        case .verify: "Verify"
        }
    }

    var subtitle: String {
        switch self {
        case .identity: "Set the first trusted user."
        case .machine: "Name the physical place this Jarvis belongs to."
        case .brainIntro: "Enable or link the central intelligence."
        case .brainLink: "Connect this Mac to the existing Brain."
        case .brainConfig: "Configure the local Brain service."
        case .aiProviders: "Choose reasoning and search providers."
        case .whatsappIntro: "Decide whether this Mac handles WhatsApp."
        case .whatsappConfig: "Check or link the WhatsApp account."
        case .intercomIntro: "Decide whether this Mac listens and speaks."
        case .voiceProviders: "Choose STT and TTS providers."
        case .workerIntro: "Decide whether this Mac builds and controls."
        case .workerConfig: "Choose project and Mac-control settings."
        case .review: "Check the exact setup before applying."
        case .verify: "Confirm the machine is ready."
        }
    }

    var symbolName: String {
        switch self {
        case .identity: "person.crop.circle.badge.checkmark"
        case .machine: "desktopcomputer"
        case .brainIntro: "brain.head.profile"
        case .brainLink: "link"
        case .brainConfig: "server.rack"
        case .aiProviders: "sparkles"
        case .whatsappIntro: "message.badge"
        case .whatsappConfig: "qrcode.viewfinder"
        case .intercomIntro: "waveform.badge.mic"
        case .voiceProviders: "waveform.and.mic"
        case .workerIntro: "hammer.circle"
        case .workerConfig: "desktopcomputer.and.arrow.down"
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

struct WizardSection<Content: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SetupHeroLine(icon: icon, title: title, detail: detail)
            content
        }
    }
}

struct CapabilityDecisionStep: View {
    let icon: String
    let title: String
    let detail: String
    let enabled: Bool
    let enableTitle: String
    let skipTitle: String
    let enable: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SetupHeroLine(icon: icon, title: title, detail: detail)
            HStack(spacing: 12) {
                Button(action: enable) {
                    Label(enableTitle, systemImage: enabled ? "checkmark.circle.fill" : "plus.circle")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(enableTitle)
                .accessibilityValue(enabled ? "Enabled" : "Not enabled")
                Button(action: skip) {
                    Label(skipTitle, systemImage: "arrow.right")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(skipTitle)
            }
            StatusNote(
                icon: enabled ? "checkmark.seal" : "circle.dashed",
                text: enabled ? "Enabled for this Mac. The next screen collects only the fields this capability needs." : "Skipped for now. You can replay setup and enable it later."
            )
        }
    }
}

struct BrainModeButton: View {
    let title: String
    let detail: String
    let icon: String
    let selected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? Color.green : Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color(nsColor: selected ? .selectedContentBackgroundColor : .controlBackgroundColor).opacity(selected ? 0.16 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(detail)
        .accessibilityIdentifier(identifier)
    }
}

struct StatusNote: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct WizardField<Content: View>: View {
    let title: String
    var description: String = ""
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WizardSecret: View {
    let title: String
    var description: String = ""
    @Binding var value: String
    let alreadySet: Bool

    var body: some View {
        WizardField(title: title, description: description) {
            HStack(spacing: 8) {
                SecureField(alreadySet ? "Already set; leave blank to keep" : "Paste key", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(title)
                    .accessibilityHint(description.isEmpty ? "Secret value" : description)
                if alreadySet {
                    Label("Set", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

struct CountryPhoneField: View {
    @Binding var country: PhoneCountry
    @Binding var number: String
    let identifier: String
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    TextField("Search country", text: $search)
                    ForEach(filteredCountries) { candidate in
                        Button {
                            country = candidate
                        } label: {
                            Text("\(candidate.flag) \(candidate.name) \(candidate.dialCode)")
                        }
                    }
                } label: {
                    Text("\(country.flag) \(country.dialCode)")
                        .frame(width: 88)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Country")
                .accessibilityValue("\(country.name) \(country.dialCode)")
                TextField("7921 815819", text: $number)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier(identifier)
                    .accessibilityLabel("Phone number")
            }
            Text("Will save as \(country.normalized(number).isEmpty ? "not set" : country.normalized(number)).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Saved phone number preview")
        }
    }

    private var filteredCountries: [PhoneCountry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return PhoneCountry.all }
        return PhoneCountry.all.filter {
            $0.name.lowercased().contains(query)
                || $0.dialCode.contains(query)
                || $0.iso.lowercased().contains(query)
        }
    }
}

struct PhoneCountry: Identifiable, Equatable {
    let iso: String
    let flag: String
    let name: String
    let dialCode: String

    var id: String { iso }

    static let all: [PhoneCountry] = [
        PhoneCountry(iso: "GB", flag: "🇬🇧", name: "United Kingdom", dialCode: "+44"),
        PhoneCountry(iso: "US", flag: "🇺🇸", name: "United States", dialCode: "+1"),
        PhoneCountry(iso: "IE", flag: "🇮🇪", name: "Ireland", dialCode: "+353"),
        PhoneCountry(iso: "AU", flag: "🇦🇺", name: "Australia", dialCode: "+61"),
        PhoneCountry(iso: "CA", flag: "🇨🇦", name: "Canada", dialCode: "+1"),
        PhoneCountry(iso: "FR", flag: "🇫🇷", name: "France", dialCode: "+33"),
        PhoneCountry(iso: "DE", flag: "🇩🇪", name: "Germany", dialCode: "+49"),
        PhoneCountry(iso: "ES", flag: "🇪🇸", name: "Spain", dialCode: "+34"),
        PhoneCountry(iso: "NL", flag: "🇳🇱", name: "Netherlands", dialCode: "+31"),
        PhoneCountry(iso: "IN", flag: "🇮🇳", name: "India", dialCode: "+91")
    ]

    static let defaultCountry = all[0]

    static func country(matching value: String) -> PhoneCountry? {
        let digits = value.filter(\.isNumber)
        return all.first { country in
            digits.hasPrefix(country.dialCode.filter(\.isNumber))
        }
    }

    static func localNumber(from value: String, country: PhoneCountry) -> String {
        var digits = value.filter(\.isNumber)
        let countryDigits = country.dialCode.filter(\.isNumber)
        if digits.hasPrefix(countryDigits) {
            digits.removeFirst(countryDigits.count)
        }
        return digits
    }

    func normalized(_ value: String) -> String {
        var digits = value.filter(\.isNumber)
        let countryDigits = dialCode.filter(\.isNumber)
        if digits.hasPrefix(countryDigits) {
            digits.removeFirst(countryDigits.count)
        }
        while digits.hasPrefix("0") {
            digits.removeFirst()
        }
        return digits.isEmpty ? "" : dialCode + digits
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
