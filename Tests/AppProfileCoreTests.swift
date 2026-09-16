import Foundation

@main
struct AppProfileCoreTests {
    enum TestError: Error { case failed(String) }

    static func main() throws {
        try testExactBundleMatchAndOverrides()
        try testDisabledUnknownAndMissingAppFallBack()
        try testPartialProfileInheritsUnspecifiedValues()
        try testJSONRoundTrip()
        print("AppProfileCoreTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static let developer = AppProfile(
        name: "Developer",
        bundleIdentifiers: ["com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"],
        isEnabled: true,
        sttProviderID: "groq",
        sttModel: "whisper-large-v3-turbo",
        llmProviderID: "zai",
        llmModel: "glm-5.2",
        language: "auto",
        customPrompt: "Preserve code identifiers and technical English terms."
    )

    static let disabled = AppProfile(
        name: "Disabled",
        bundleIdentifiers: ["com.apple.TextEdit"],
        isEnabled: false,
        llmProviderID: "openai"
    )

    static let partial = AppProfile(
        name: "LINE",
        bundleIdentifiers: ["jp.naver.line.mac"],
        isEnabled: true,
        language: "th"
    )

    static let document = AppProfileDocument(profiles: [developer, disabled, partial])

    static func testExactBundleMatchAndOverrides() throws {
        let vscode = AppProfileResolver.resolve(bundleIdentifier: "com.microsoft.VSCode", in: document)
        try expect(vscode?.id == developer.id, "exact bundle ID should resolve enabled profile")
        try expect(vscode?.llmProviderID == "zai", "profile should carry LLM provider override")
        try expect(vscode?.customPrompt?.contains("technical English") == true, "profile should carry custom prompt")
    }

    static func testDisabledUnknownAndMissingAppFallBack() throws {
        try expect(AppProfileResolver.resolve(bundleIdentifier: "com.apple.TextEdit", in: document) == nil,
                   "disabled profiles must not resolve")
        try expect(AppProfileResolver.resolve(bundleIdentifier: "com.example.Unknown", in: document) == nil,
                   "unknown bundle IDs should inherit global settings")
        try expect(AppProfileResolver.resolve(bundleIdentifier: nil, in: document) == nil,
                   "missing foreground app should inherit global settings")
    }

    static func testPartialProfileInheritsUnspecifiedValues() throws {
        let line = AppProfileResolver.resolve(bundleIdentifier: "jp.naver.line.mac", in: document)
        try expect(line?.language == "th", "partial profile should override language")
        try expect(line?.sttProviderID == nil, "unspecified STT provider must inherit global settings")
        try expect(line?.llmProviderID == nil, "unspecified LLM provider must inherit global settings")
    }

    static func testJSONRoundTrip() throws {
        let encoded = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(AppProfileDocument.self, from: encoded)
        try expect(decoded == document, "profiles must round-trip through JSON persistence")
    }
}
