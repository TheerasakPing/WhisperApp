import Foundation

@main
struct ProviderCoreTests {
    static func main() throws {
        try testRegistryCoverage()
        try testCurrentProviderDefaults()
        try testResponsesProviderPresets()
        try testResponsesRequestShape()
        try testResponsesTextExtraction()
        try testKimiRequestPolicy()
        try testDoubaoOpenAICompatibility()
        try testModelCatalogParser()
        try testOpenAIRequestIncludesTemperatureWhenSupported()
        try testRequestOmitsTemperatureWhenUnsupported()
        try testAnthropicPayloadAndHeaders()
        try testGLMThinkingPolicyIsCapabilityDriven()
        try testLocalProviderDoesNotRequireAuth()
        print("ProviderCoreTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError(message) }
    }

    static func testRegistryCoverage() throws {
        let ids = Set(LLMRegistry.all.map(\.id))
        for id in ["openai", "openai_responses", "anthropic", "gemini", "xai", "xai_responses", "groq", "openrouter", "deepseek", "qwen", "qwen_responses", "glm", "minimax", "moonshot", "doubao", "custom"] {
            try expect(ids.contains(id), "missing provider: \(id)")
        }
        try expect(LLMRegistry.provider(id: "groq").defaultModel == "llama-3.3-70b-versatile",
                   "Groq default changed unexpectedly")
    }

    static func testCurrentProviderDefaults() throws {
        try expect(LLMRegistry.provider(id: "deepseek").defaultModel == "deepseek-flash",
                   "DeepSeek must not default to retired legacy model names")
        try expect(LLMRegistry.provider(id: "deepseek").modelsEndpoint == "https://api.deepseek.com/models",
                   "DeepSeek models endpoint missing")
        try expect(LLMRegistry.provider(id: "gemini").defaultModel == "gemini-3.8-flash",
                   "Gemini default should track the current OpenAI-compatible example")
        try expect(LLMRegistry.provider(id: "gemini").modelsEndpoint == "https://generativelanguage.googleapis.com/v1beta/openai/models",
                   "Gemini models endpoint missing")
        try expect(LLMRegistry.provider(id: "anthropic").defaultModel == "claude-haiku-4-5-20251001",
                   "Anthropic default should use the active exact Haiku model ID")
        try expect(LLMRegistry.provider(id: "anthropic").modelsEndpoint == "https://api.anthropic.com/v1/models",
                   "Anthropic models endpoint missing")
        try expect(LLMRegistry.provider(id: "moonshot").defaultModel == "kimi-k2.6",
                   "Kimi default should use the documented chat-completions model")
        try expect(LLMRegistry.provider(id: "moonshot").modelsEndpoint == "https://api.moonshot.ai/v1/models",
                   "Kimi models endpoint missing")
        try expect(LLMRegistry.provider(id: "doubao").defaultEndpoint == "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
                   "Doubao Ark endpoint mismatch")
    }

    static func testResponsesProviderPresets() throws {
        let openai = LLMRegistry.provider(id: "openai_responses")
        try expect(openai.apiProtocol == .openAIResponses, "OpenAI Responses preset protocol mismatch")
        try expect(openai.defaultEndpoint == "https://api.openai.com/v1/responses", "OpenAI Responses endpoint mismatch")
        try expect(openai.defaultModel == "gpt-5.6-luna", "OpenAI Responses default should use the cost-sensitive GPT-5.6 model")

        let xai = LLMRegistry.provider(id: "xai_responses")
        try expect(xai.apiProtocol == .openAIResponses, "xAI Responses preset protocol mismatch")
        try expect(xai.defaultEndpoint == "https://api.x.ai/v1/responses", "xAI Responses endpoint mismatch")
        try expect(xai.defaultModel == "grok-4.6", "xAI Responses default model mismatch")

        let qwen = LLMRegistry.provider(id: "qwen_responses")
        try expect(qwen.apiProtocol == .openAIResponses, "Qwen Responses preset protocol mismatch")
        try expect(qwen.defaultEndpoint.isEmpty, "Qwen Responses endpoint must stay workspace-specific")
        try expect(qwen.defaultModel == "qwen3.8-flash", "Qwen Responses default model mismatch")
    }

    static func testResponsesRequestShape() throws {
        let p = LLMRegistry.provider(id: "xai_responses")
        let spec = LLMRequestBuilder.build(provider: p, model: p.defaultModel,
                                           systemPrompt: "correct only", userText: "helo")
        try expect(spec.apiProtocol == .openAIResponses, "Responses request protocol mismatch")
        try expect((spec.body["model"] as? String) == "grok-4.6", "Responses model missing")
        try expect((spec.body["store"] as? Bool) == false, "Responses correction requests must disable storage")
        try expect(spec.body["temperature"] == nil, "Responses compatibility path should omit temperature")
        let input = spec.body["input"] as? [[String: String]]
        try expect(input?.count == 2, "Responses input should contain system and user messages")
        try expect(input?.first?["role"] == "system", "Responses system message missing")
        try expect(input?.last?["content"] == "helo", "Responses user input missing")
    }

    static func testResponsesTextExtraction() throws {
        let json: [String: Any] = [
            "output": [[
                "type": "message",
                "content": [
                    ["type": "output_text", "text": "hello"],
                    ["type": "refusal", "refusal": "ignored"],
                ],
            ]]
        ]
        try expect(LLMRequestBuilder.extractText(from: json, apiProtocol: .openAIResponses) == "hello",
                   "Responses output_text extraction failed")
    }

    static func testKimiRequestPolicy() throws {
        let p = LLMRegistry.provider(id: "moonshot")
        let spec = LLMRequestBuilder.build(provider: p, model: p.defaultModel,
                                           systemPrompt: "sys", userText: "hello")
        try expect(spec.apiProtocol == .openAIChat, "Kimi should use OpenAI Chat Completions")
        try expect(spec.body["temperature"] == nil, "Kimi K2.6 docs recommend omitting temperature")
        let thinking = spec.body["thinking"] as? [String: String]
        try expect(thinking?["type"] == "disabled", "Kimi correction should disable thinking")
    }

    static func testDoubaoOpenAICompatibility() throws {
        let p = LLMRegistry.provider(id: "doubao")
        let spec = LLMRequestBuilder.build(provider: p, model: "doubao-seed-2-1-pro-260628",
                                           systemPrompt: "sys", userText: "hello")
        try expect(spec.apiProtocol == .openAIChat, "Doubao should use OpenAI Chat Completions")
        try expect(spec.headers["Authorization"] == "Bearer {API_KEY}", "Doubao bearer auth missing")
    }

    static func testModelCatalogParser() throws {
        let json: [String: Any] = [
            "data": [
                ["id": "model-b"],
                ["id": "model-a"],
                ["name": "ignored"],
                ["id": "model-a"],
            ]
        ]
        try expect(LLMModelCatalog.modelIDs(from: json) == ["model-b", "model-a"],
                   "model catalog must preserve provider order and deduplicate ids")
    }

    static func testOpenAIRequestIncludesTemperatureWhenSupported() throws {
        let p = LLMRegistry.provider(id: "groq")
        let spec = LLMRequestBuilder.build(provider: p, model: p.defaultModel,
                                           systemPrompt: "sys", userText: "hello")
        try expect(spec.headers["Authorization"] == "Bearer {API_KEY}", "OpenAI auth template mismatch")
        try expect((spec.body["temperature"] as? Double) == 0.2, "temperature should be present")
        try expect(spec.apiProtocol == .openAIChat, "Groq should use OpenAI chat")
    }

    static func testRequestOmitsTemperatureWhenUnsupported() throws {
        var p = LLMRegistry.provider(id: "anthropic")
        p = p.withCapabilities(LLMCapabilities(supportsTemperature: false))
        let spec = LLMRequestBuilder.build(provider: p, model: p.defaultModel,
                                           systemPrompt: "sys", userText: "hello")
        try expect(spec.body["temperature"] == nil, "temperature must be omitted when unsupported")
    }

    static func testAnthropicPayloadAndHeaders() throws {
        let p = LLMRegistry.provider(id: "anthropic")
        let spec = LLMRequestBuilder.build(provider: p, model: p.defaultModel,
                                           systemPrompt: "sys", userText: "hello")
        try expect(spec.apiProtocol == .anthropicMessages, "Anthropic protocol mismatch")
        try expect(spec.headers["x-api-key"] == "{API_KEY}", "Anthropic auth template mismatch")
        try expect(spec.headers["anthropic-version"] == "2023-06-01", "Anthropic version missing")
        try expect((spec.body["system"] as? String) == "sys", "Anthropic system prompt missing")
    }

    static func testLocalProviderDoesNotRequireAuth() throws {
        let p = LLMRegistry.provider(id: "ollama")
        let spec = LLMRequestBuilder.build(provider: p, model: "llama3",
                                           systemPrompt: "sys", userText: "hello")
        try expect(p.requiresAPIKey == false, "Ollama should not require an API key")
        try expect(spec.headers["Authorization"] == nil, "Ollama must not send a fake bearer token")
    }

    static func testGLMThinkingPolicyIsCapabilityDriven() throws {
        let p = LLMRegistry.provider(id: "glm")
        let spec = LLMRequestBuilder.build(provider: p, model: "not-named-glm-anymore",
                                           systemPrompt: "sys", userText: "hello")
        let thinking = spec.body["thinking"] as? [String: String]
        try expect(thinking?["type"] == "disabled",
                   "GLM thinking disable must come from provider capability")
    }
}

struct TestError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
