import Foundation

@main
struct AIActionCoreTests {
    enum TestError: Error { case failed(String) }
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        try testActionCatalog()
        try testStylePromptsPreserveMeaning()
        try testTranslationPrompts()
        try testSummaryPrompt()
        try testOutputNormalization()
        print("AIActionCoreTests: PASS")
    }

    static func testActionCatalog() throws {
        let ids = AIAction.allCases.map(\.rawValue)
        try expect(Set(ids).count == ids.count, "AI action IDs must be unique")
        try expect(ids == ["polite", "concise", "formal", "summarize", "translate_th", "translate_en"],
                   "command mode must expose the approved deterministic action catalog")
    }

    static func testStylePromptsPreserveMeaning() throws {
        for action in [AIAction.polite, .concise, .formal] {
            let prompt = AIActionPrompt.systemPrompt(for: action)
            try expect(prompt.contains("preserve the original meaning"),
                       "style actions must preserve meaning")
            try expect(prompt.contains("Return only"),
                       "actions must request text-only output")
        }
    }

    static func testTranslationPrompts() throws {
        try expect(
            AIActionPrompt.systemPrompt(for: .translateThai).contains("Thai"),
            "translate_th must target Thai"
        )
        try expect(
            AIActionPrompt.systemPrompt(for: .translateEnglish).contains("English"),
            "translate_en must target English"
        )
    }

    static func testSummaryPrompt() throws {
        let prompt = AIActionPrompt.systemPrompt(for: .summarize)
        try expect(prompt.contains("concise summary"), "summary action must request concise summary")
        try expect(prompt.contains("Do not invent"), "summary action must forbid invented facts")
    }

    static func testOutputNormalization() throws {
        try expect(AIActionPrompt.normalizeOutput("  \"Hello\"  ") == "Hello",
                   "single wrapping quotes must be removed")
        try expect(AIActionPrompt.normalizeOutput("  hello\nworld  ") == "hello\nworld",
                   "content whitespace inside the result must be preserved")
        try expect(AIActionPrompt.normalizeOutput("   ") == nil,
                   "blank model output must be rejected")
    }
}
