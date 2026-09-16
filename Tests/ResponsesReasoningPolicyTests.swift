import Foundation

@main
struct ResponsesReasoningPolicyTests {
    static func main() throws {
        try expectEffort(providerID: "openai_responses", expected: "none")
        try expectEffort(providerID: "xai_responses", expected: "low")
        try expectEffort(providerID: "qwen_responses", expected: "none")
        print("ResponsesReasoningPolicyTests: PASS")
    }

    static func expectEffort(providerID: String, expected: String) throws {
        let provider = LLMRegistry.provider(id: providerID)
        let spec = LLMRequestBuilder.build(provider: provider,
                                           model: provider.defaultModel,
                                           systemPrompt: "Correct text only",
                                           userText: "helo")
        let reasoning = spec.body["reasoning"] as? [String: String]
        guard reasoning?["effort"] == expected else {
            throw ResponsesPolicyError("\(providerID) reasoning effort must be \(expected)")
        }
    }
}

struct ResponsesPolicyError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
