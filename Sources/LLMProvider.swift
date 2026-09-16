import Foundation

/// Manages provider settings: selected provider + key/model/endpoint per provider.
/// Provider metadata and request policies live in LLMProviderCore.swift.
enum LLMSettings {
    private static let defaults = UserDefaults.standard
    private static let providerKey = "llm.provider"

    static var providerID: String {
        get { defaults.string(forKey: providerKey) ?? "groq" }
        set { defaults.set(newValue, forKey: providerKey) }
    }

    static var current: LLMProvider { LLMRegistry.provider(id: providerID) }

    private static func keyPath(_ p: LLMProvider) -> String {
        KeyStore.dir + "/llm_\(p.id).key"
    }

    static func savedKeyFile(for p: LLMProvider) -> String {
        if let k = try? String(contentsOfFile: keyPath(p), encoding: .utf8) {
            return k.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if p.id == "deepseek",
           let k = try? String(contentsOfFile: KeyStore.dir + "/deepseek.key", encoding: .utf8) {
            return k.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    static func key(for p: LLMProvider) -> String? {
        let saved = savedKeyFile(for: p)
        if !saved.isEmpty { return saved }
        return ShellEnv.value(p.envKey)
    }

    static func saveKey(_ key: String, for p: LLMProvider) {
        try? FileManager.default.createDirectory(atPath: KeyStore.dir, withIntermediateDirectories: true)
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = keyPath(p)
        if t.isEmpty {
            try? FileManager.default.removeItem(atPath: path)
            return
        }
        try? t.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    static func model(for p: LLMProvider) -> String {
        let custom = savedModel(for: p).trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? p.defaultModel : custom
    }

    static func saveModel(_ model: String, for p: LLMProvider) {
        defaults.set(model.trimmingCharacters(in: .whitespacesAndNewlines),
                     forKey: "llm.model.\(p.id)")
    }

    static func savedModel(for p: LLMProvider) -> String {
        defaults.string(forKey: "llm.model.\(p.id)") ?? ""
    }

    static func endpoint(for p: LLMProvider) -> URL? {
        let value = endpointString(for: p).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

    static func endpointString(for p: LLMProvider) -> String {
        let custom = savedEndpoint(for: p).trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }

        // Backward compatibility: honor DeepSeek endpoint/base variables used by older releases.
        if p.id == "deepseek" { return KeyStore.deepseekEndpoint().absoluteString }
        return p.defaultEndpoint
    }

    static func saveEndpoint(_ endpoint: String, for p: LLMProvider) {
        defaults.set(endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                     forKey: "llm.endpoint.\(p.id)")
    }

    static func savedEndpoint(for p: LLMProvider) -> String {
        defaults.string(forKey: "llm.endpoint.\(p.id)") ?? ""
    }

    static func isConfigured(_ p: LLMProvider) -> Bool {
        let authOK = !p.requiresAPIKey || key(for: p) != nil
        return authOK && !endpointString(for: p).isEmpty && !model(for: p).isEmpty
    }
}
