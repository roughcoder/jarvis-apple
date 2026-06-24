import Foundation

struct SetupState: Codable, Equatable {
    var admin: SetupAdmin
    var machine: SetupMachine
    var roles: Set<JarvisRole>
    var providers: SetupProviders
    var brain: SetupBrain
    var intercom: SetupIntercom
    var worker: SetupWorker
    var whatsapp: SetupWhatsApp

    static var empty: SetupState {
        SetupState(
            admin: SetupAdmin(),
            machine: SetupMachine(),
            roles: [],
            providers: SetupProviders(),
            brain: SetupBrain(),
            intercom: SetupIntercom(),
            worker: SetupWorker(),
            whatsapp: SetupWhatsApp()
        )
    }

    enum CodingKeys: String, CodingKey {
        case admin, machine, roles, providers, brain, intercom, worker, whatsapp
    }
}

struct SetupAdmin: Codable, Equatable {
    var name = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()
    var email = ""
    var phone = ""
    var whatsappAdmin = ""

    enum CodingKeys: String, CodingKey {
        case name, email, phone
        case whatsappAdmin = "whatsapp_admin"
    }
}

struct SetupMachine: Codable, Equatable {
    var deviceID = Host.current().localizedName?.lowercased().replacingOccurrences(of: " ", with: "-") ?? "local-mac"
    var room = "default"
    var personal = true

    enum CodingKeys: String, CodingKey {
        case room, personal
        case deviceID = "device_id"
    }
}

struct SetupProviders: Codable, Equatable {
    var anthropicAPIKey = ""
    var geminiAPIKey = ""
    var openAIAPIKey = ""
    var openRouterAPIKey = ""
    var toolsWebsearchAPIKey = ""
    var ttsAPIKey = ""
    var workerPeekabooOpenAIAPIKey = ""
    var workerPeekabooOpenRouterAPIKey = ""
    var hasAnthropicAPIKey = false
    var hasGeminiAPIKey = false
    var hasOpenAIAPIKey = false
    var hasOpenRouterAPIKey = false
    var hasToolsWebsearchAPIKey = false
    var hasTTSAPIKey = false
    var hasWorkerPeekabooOpenAIAPIKey = false
    var hasWorkerPeekabooOpenRouterAPIKey = false

    enum CodingKeys: String, CodingKey {
        case anthropicAPIKey = "anthropic_api_key"
        case geminiAPIKey = "gemini_api_key"
        case openAIAPIKey = "openai_api_key"
        case openRouterAPIKey = "openrouter_api_key"
        case toolsWebsearchAPIKey = "tools_websearch_api_key"
        case ttsAPIKey = "tts_api_key"
        case workerPeekabooOpenAIAPIKey = "worker_peekaboo_openai_api_key"
        case workerPeekabooOpenRouterAPIKey = "worker_peekaboo_openrouter_api_key"
        case hasAnthropicAPIKey = "has_anthropic_api_key"
        case hasGeminiAPIKey = "has_gemini_api_key"
        case hasOpenAIAPIKey = "has_openai_api_key"
        case hasOpenRouterAPIKey = "has_openrouter_api_key"
        case hasToolsWebsearchAPIKey = "has_tools_websearch_api_key"
        case hasTTSAPIKey = "has_tts_api_key"
        case hasWorkerPeekabooOpenAIAPIKey = "has_worker_peekaboo_openai_api_key"
        case hasWorkerPeekabooOpenRouterAPIKey = "has_worker_peekaboo_openrouter_api_key"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anthropicAPIKey = try container.decodeIfPresent(String.self, forKey: .anthropicAPIKey) ?? ""
        geminiAPIKey = try container.decodeIfPresent(String.self, forKey: .geminiAPIKey) ?? ""
        openAIAPIKey = try container.decodeIfPresent(String.self, forKey: .openAIAPIKey) ?? ""
        openRouterAPIKey = try container.decodeIfPresent(String.self, forKey: .openRouterAPIKey) ?? ""
        toolsWebsearchAPIKey = try container.decodeIfPresent(String.self, forKey: .toolsWebsearchAPIKey) ?? ""
        ttsAPIKey = try container.decodeIfPresent(String.self, forKey: .ttsAPIKey) ?? ""
        workerPeekabooOpenAIAPIKey = try container.decodeIfPresent(String.self, forKey: .workerPeekabooOpenAIAPIKey) ?? ""
        workerPeekabooOpenRouterAPIKey = try container.decodeIfPresent(String.self, forKey: .workerPeekabooOpenRouterAPIKey) ?? ""
        hasAnthropicAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasAnthropicAPIKey) ?? false
        hasGeminiAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasGeminiAPIKey) ?? false
        hasOpenAIAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasOpenAIAPIKey) ?? false
        hasOpenRouterAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasOpenRouterAPIKey) ?? false
        hasToolsWebsearchAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasToolsWebsearchAPIKey) ?? false
        hasTTSAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasTTSAPIKey) ?? false
        hasWorkerPeekabooOpenAIAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasWorkerPeekabooOpenAIAPIKey) ?? false
        hasWorkerPeekabooOpenRouterAPIKey = try container.decodeIfPresent(Bool.self, forKey: .hasWorkerPeekabooOpenRouterAPIKey) ?? false
    }
}

struct SetupBrain: Codable, Equatable {
    var host = "0.0.0.0"
    var port = "8700"
}

struct SetupIntercom: Codable, Equatable {
    var brainHost = ""
    var brainPort = "8700"
    var token = ""
    var paired = false

    enum CodingKeys: String, CodingKey {
        case token, paired
        case brainHost = "brain_host"
        case brainPort = "brain_port"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brainHost = try container.decodeIfPresent(String.self, forKey: .brainHost) ?? ""
        brainPort = try container.decodeIfPresent(String.self, forKey: .brainPort) ?? "8700"
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        paired = try container.decodeIfPresent(Bool.self, forKey: .paired) ?? false
    }
}

struct SetupWorker: Codable, Equatable {
    var repoRoot = ""
    var agent = "codex"
    var shellSecrets = ""
    var peekabooAIProviders = ""
    var peekabooOpenAIBaseURL = ""
    var peekabooAgentModel = "gpt-5.5"

    enum CodingKeys: String, CodingKey {
        case agent
        case repoRoot = "repo_root"
        case shellSecrets = "shell_secrets"
        case peekabooAIProviders = "peekaboo_ai_providers"
        case peekabooOpenAIBaseURL = "peekaboo_openai_base_url"
        case peekabooAgentModel = "peekaboo_agent_model"
    }
}

struct SetupWhatsApp: Codable, Equatable {
    var enabled = false
    var admin = ""
    var dmPolicy = "pairing"
    var account = ""
    var deviceID = "whatsapp"

    enum CodingKeys: String, CodingKey {
        case enabled, admin, account
        case dmPolicy = "dm_policy"
        case deviceID = "device_id"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        admin = try container.decodeIfPresent(String.self, forKey: .admin) ?? ""
        dmPolicy = try container.decodeIfPresent(String.self, forKey: .dmPolicy) ?? "pairing"
        account = try container.decodeIfPresent(String.self, forKey: .account) ?? ""
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? "whatsapp"
    }
}

struct SetupApplyResult: Codable, Equatable {
    let envFile: String
    let userFile: String
    let roles: [JarvisRole]
    let changedKeys: [String]

    enum CodingKeys: String, CodingKey {
        case roles
        case envFile = "env_file"
        case userFile = "user_file"
        case changedKeys = "changed_keys"
    }
}

struct SetupValidation: Codable, Equatable {
    let ok: Bool
    let missing: [String]
    let warnings: [String]
}

struct WhatsAppAuthResult: Codable, Equatable {
    let ok: Bool
    let argv: [String]
    let returncode: Int
    let stdout: String
    let stderr: String
}
