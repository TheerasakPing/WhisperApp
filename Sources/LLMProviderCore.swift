import Foundation

/// Wire protocol used by a provider. Vendor and protocol are intentionally separate:
/// many vendors expose OpenAI-compatible APIs while others use Anthropic Messages.
enum LLMAPIProtocol: String, Hashable {
    case openAIChat
    case anthropicMessages
}

enum LLMAuthStyle: String, Hashable {
    case bearer
    case anthropicKey
    case none
}

enum LLMThinkingPolicy: String, Hashable {
    case none
    case disableAnthropicThinking
}

struct LLMCapabilities: Hashable {
    let supportsTemperature: Bool
    let thinkingPolicy: LLMThinkingPolicy

    init(supportsTemperature: Bool = true,
         thinkingPolicy: LLMThinkingPolicy = .none) {
        self.supportsTemperature = supportsTemperature
        self.thinkingPolicy = thinkingPolicy
    }
}

struct LLMProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let defaultEndpoint: String
    let defaultModel: String
    let modelsEndpoint: String?
    let envKey: String
    let apiProtocol: LLMAPIProtocol
    let authStyle: LLMAuthStyle
    let capabilities: LLMCapabilities
    let isCustom: Bool

    init(id: String,
         name: String,
         defaultEndpoint: String,
         defaultModel: String,
         modelsEndpoint: String? = nil,
         envKey: String,
         apiProtocol: LLMAPIProtocol,
         authStyle: LLMAuthStyle? = nil,
         capabilities: LLMCapabilities = LLMCapabilities(),
         isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.defaultEndpoint = defaultEndpoint
        self.defaultModel = defaultModel
        self.modelsEndpoint = modelsEndpoint
        self.envKey = envKey
        self.apiProtocol = apiProtocol
        self.authStyle = authStyle ?? (apiProtocol == .anthropicMessages ? .anthropicKey : .bearer)
        self.capabilities = capabilities
        self.isCustom = isCustom
    }

    func withCapabilities(_ capabilities: LLMCapabilities) -> LLMProvider {
        LLMProvider(id: id, name: name, defaultEndpoint: defaultEndpoint,
                    defaultModel: defaultModel, modelsEndpoint: modelsEndpoint,
                    envKey: envKey, apiProtocol: apiProtocol, authStyle: authStyle,
                    capabilities: capabilities, isCustom: isCustom)
    }

    var requiresAPIKey: Bool { authStyle != .none }
}

enum LLMRegistry {
    static let all: [LLMProvider] = [
        // USA / global
        LLMProvider(id: "groq", name: "Groq",
                    defaultEndpoint: "https://api.groq.com/openai/v1/chat/completions",
                    defaultModel: "llama-3.3-70b-versatile",
                    modelsEndpoint: "https://api.groq.com/openai/v1/models",
                    envKey: "GROQ_API_KEY", apiProtocol: .openAIChat),
        LLMProvider(id: "openai", name: "OpenAI",
                    defaultEndpoint: "https://api.openai.com/v1/chat/completions",
                    defaultModel: "gpt-4o-mini",
                    modelsEndpoint: "https://api.openai.com/v1/models",
                    envKey: "OPENAI_API_KEY", apiProtocol: .openAIChat),
        LLMProvider(id: "anthropic", name: "Anthropic (Claude)",
                    defaultEndpoint: "https://api.anthropic.com/v1/messages",
                    defaultModel: "claude-haiku-4-5-20251001",
                    modelsEndpoint: "https://api.anthropic.com/v1/models",
                    envKey: "ANTHROPIC_API_KEY", apiProtocol: .anthropicMessages,
                    capabilities: LLMCapabilities(supportsTemperature: false)),
        LLMProvider(id: "gemini", name: "Google Gemini",
                    defaultEndpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
                    defaultModel: "gemini-3.8-flash",
                    modelsEndpoint: "https://generativelanguage.googleapis.com/v1beta/openai/models",
                    envKey: "GEMINI_API_KEY", apiProtocol: .openAIChat),
        LLMProvider(id: "xai", name: "xAI (Grok)",
                    defaultEndpoint: "https://api.x.ai/v1/chat/completions",
                    defaultModel: "latest",
                    modelsEndpoint: "https://api.x.ai/v1/models",
                    envKey: "XAI_API_KEY", apiProtocol: .openAIChat),
        LLMProvider(id: "openrouter", name: "OpenRouter",
                    defaultEndpoint: "https://openrouter.ai/api/v1/chat/completions",
                    defaultModel: "google/gemini-2.0-flash-001",
                    modelsEndpoint: "https://openrouter.ai/api/v1/models",
                    envKey: "OPENROUTER_API_KEY", apiProtocol: .openAIChat),

        // China / Chinese vendors
        LLMProvider(id: "deepseek", name: "DeepSeek",
                    defaultEndpoint: "https://api.deepseek.com/chat/completions",
                    defaultModel: "deepseek-flash",
                    modelsEndpoint: "https://api.deepseek.com/models",
                    envKey: "DEEPSEEK_API_KEY", apiProtocol: .openAIChat),
        LLMProvider(id: "qwen", name: "Alibaba Qwen / Model Studio",
                    defaultEndpoint: "",
                    defaultModel: "qwen3.8-flash",
                    envKey: "DASHSCOPE_API_KEY", apiProtocol: .openAIChat,
                    isCustom: true),
        LLMProvider(id: "glm", name: "GLM (Z.AI)",
                    defaultEndpoint: "https://api.z.ai/api/anthropic/v1/messages",
                    defaultModel: "glm-5.2",
                    envKey: "ZAI_API_KEY", apiProtocol: .anthropicMessages,
                    capabilities: LLMCapabilities(supportsTemperature: true,
                                                  thinkingPolicy: .disableAnthropicThinking)),
        LLMProvider(id: "minimax", name: "MiniMax",
                    defaultEndpoint: "https://api.minimax.io/v1/chat/completions",
                    defaultModel: "MiniMax-M2.7",
                    modelsEndpoint: "https://api.minimax.io/v1/models",
                    envKey: "MINIMAX_API_KEY", apiProtocol: .openAIChat),

        // Local / self-hosted OpenAI-compatible servers
        LLMProvider(id: "ollama", name: "Ollama (Local)",
                    defaultEndpoint: "http://127.0.0.1:11434/v1/chat/completions",
                    defaultModel: "",
                    modelsEndpoint: "http://127.0.0.1:11434/v1/models",
                    envKey: "OLLAMA_API_KEY", apiProtocol: .openAIChat,
                    authStyle: LLMAuthStyle.none, isCustom: true),
        LLMProvider(id: "lmstudio", name: "LM Studio (Local)",
                    defaultEndpoint: "http://127.0.0.1:1234/v1/chat/completions",
                    defaultModel: "",
                    modelsEndpoint: "http://127.0.0.1:1234/v1/models",
                    envKey: "LMSTUDIO_API_KEY", apiProtocol: .openAIChat,
                    authStyle: LLMAuthStyle.none, isCustom: true),
        LLMProvider(id: "custom", name: "Custom (OpenAI-compatible)",
                    defaultEndpoint: "", defaultModel: "", envKey: "LLM_API_KEY",
                    apiProtocol: .openAIChat, isCustom: true),
    ]

    static func provider(id: String) -> LLMProvider {
        all.first { $0.id == id } ?? all[0]
    }
}

struct LLMRequestSpec {
    let apiProtocol: LLMAPIProtocol
    let headers: [String: String]
    let body: [String: Any]
}

enum LLMRequestBuilder {
    /// Build a provider-specific request without embedding a real API key.
    /// Caller replaces {API_KEY} immediately before sending.
    static func build(provider: LLMProvider,
                      model: String,
                      systemPrompt: String,
                      userText: String) -> LLMRequestSpec {
        var headers = ["Content-Type": "application/json"]
        var body: [String: Any]

        switch provider.apiProtocol {
        case .openAIChat:
            body = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userText],
                ],
            ]
        case .anthropicMessages:
            headers["anthropic-version"] = "2023-06-01"
            body = [
                "model": model,
                "max_tokens": 8192,
                "system": systemPrompt,
                "messages": [
                    ["role": "user", "content": userText],
                ],
            ]
        }

        switch provider.authStyle {
        case .bearer:
            headers["Authorization"] = "Bearer {API_KEY}"
        case .anthropicKey:
            headers["x-api-key"] = "{API_KEY}"
        case .none:
            break
        }

        if provider.capabilities.supportsTemperature {
            body["temperature"] = 0.2
        }

        if provider.capabilities.thinkingPolicy == .disableAnthropicThinking {
            body["thinking"] = ["type": "disabled"]
        }

        return LLMRequestSpec(apiProtocol: provider.apiProtocol, headers: headers, body: body)
    }

    static func extractText(from json: [String: Any], apiProtocol: LLMAPIProtocol) -> String? {
        switch apiProtocol {
        case .openAIChat:
            guard let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else { return nil }
            return content
        case .anthropicMessages:
            guard let content = json["content"] as? [[String: Any]] else { return nil }
            return content.compactMap { $0["text"] as? String }.joined()
        }
    }
}

/// Shared parser for provider model catalogs that expose an OpenAI/Anthropic-style
/// `{ "data": [{ "id": "..." }] }` response.
enum LLMModelCatalog {
    static func modelIDs(from json: [String: Any]) -> [String] {
        guard let data = json["data"] as? [[String: Any]] else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for item in data {
            guard let id = item["id"] as? String, !id.isEmpty, !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(id)
        }
        return result
    }
}
