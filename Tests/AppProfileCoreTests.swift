import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let developer = AppProfile(
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
let disabled = AppProfile(
    name: "Disabled",
    bundleIdentifiers: ["com.apple.TextEdit"],
    isEnabled: false,
    llmProviderID: "openai"
)
let partial = AppProfile(
    name: "LINE",
    bundleIdentifiers: ["jp.naver.line.mac"],
    isEnabled: true,
    language: "th"
)

let document = AppProfileDocument(profiles: [developer, disabled, partial])

let vscode = AppProfileResolver.resolve(bundleIdentifier: "com.microsoft.VSCode", in: document)
expect(vscode?.id == developer.id, "exact bundle ID should resolve the enabled developer profile")
expect(vscode?.llmProviderID == "zai", "profile should carry LLM provider override")
expect(vscode?.customPrompt?.contains("technical English") == true, "profile should carry custom prompt")

let textEdit = AppProfileResolver.resolve(bundleIdentifier: "com.apple.TextEdit", in: document)
expect(textEdit == nil, "disabled profiles must not resolve")

let unknown = AppProfileResolver.resolve(bundleIdentifier: "com.example.Unknown", in: document)
expect(unknown == nil, "unknown bundle IDs should inherit global settings")

let noApp = AppProfileResolver.resolve(bundleIdentifier: nil, in: document)
expect(noApp == nil, "missing foreground app should inherit global settings")

let line = AppProfileResolver.resolve(bundleIdentifier: "jp.naver.line.mac", in: document)
expect(line?.language == "th", "partial profile should override language")
expect(line?.sttProviderID == nil, "unspecified STT provider must inherit global settings")
expect(line?.llmProviderID == nil, "unspecified LLM provider must inherit global settings")

let encoded = try JSONEncoder().encode(document)
let decoded = try JSONDecoder().decode(AppProfileDocument.self, from: encoded)
expect(decoded == document, "profiles must round-trip through JSON persistence")

print("AppProfileCoreTests PASS")
