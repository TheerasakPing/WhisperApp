import Foundation

@main
struct ZAIProviderTests {
    enum TestError: Error { case failed(String) }

    static func main() throws {
        let provider = LLMRegistry.provider(id: "glm")
        try expect(provider.apiProtocol == .openAIChat, "Z.AI must use the documented OpenAI-compatible chat protocol")
        try expect(provider.authStyle == .bearer, "Z.AI general API must use Bearer authentication")
        try expect(provider.defaultEndpoint == "https://api.z.ai/api/paas/v4/chat/completions", "Z.AI general API endpoint mismatch")
        try expect(provider.defaultModel == "glm-5.1", "Z.AI default must use a currently documented general-API model")

        let spec = LLMRequestBuilder.build(
            provider: provider,
            model: provider.defaultModel,
            systemPrompt: "Correct only",
            userText: "helo world"
        )
        try expect(spec.headers["Authorization"] == "Bearer {API_KEY}", "Z.AI Bearer header missing")
        try expect(spec.headers["x-api-key"] == nil, "Z.AI general API must not use Anthropic x-api-key auth")
        try expect(spec.headers["anthropic-version"] == nil, "Z.AI general API must not send Anthropic version headers")
        let messages = spec.body["messages"] as? [[String: String]]
        try expect(messages?.count == 2, "Z.AI request should contain system and user messages")
        try expect(messages?.first?["role"] == "system", "Z.AI system message missing")
        try expect(messages?.last?["content"] == "helo world", "Z.AI user message missing")
        let thinking = spec.body["thinking"] as? [String: String]
        try expect(thinking?["type"] == "disabled", "Text correction should disable Z.AI deep thinking for latency")

        let response: [String: Any] = [
            "choices": [["message": ["role": "assistant", "content": "hello world"]]]
        ]
        try expect(LLMRequestBuilder.extractText(from: response, apiProtocol: provider.apiProtocol) == "hello world",
                   "Z.AI OpenAI-compatible response parsing failed")
        print("ZAIProviderTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }
}
