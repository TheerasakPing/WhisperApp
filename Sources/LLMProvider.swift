import Foundation

/// Manages provider settings: selected provider + key/model/endpoint per provider.
/// Provider metadata and request policies live in LLMProviderCore.swift.
enum LLMSettings {
    private static let defaults = UserDefaults.standard
    private static let providerKey = "llm.provider"
    private static let fallbackKey = "llm.fallback.providers"

    static var providerID: String {
        get { defaults.string(forKey: providerKey) ?? "groq" }
        set { defaults.set(newValue, forKey: providerKey) }
    }

    static var fallbackProviderIDs: [String] {
        get { defaults.stringArray(forKey: fallbackKey) ?? [] }
        set { defaults.set(Array(newValue.prefix(3)), forKey: fallbackKey) }
    }

    static var current: LLMProvider { LLMRegistry.provider(id: providerID) }

    private static func keyPath(_ p: LLMProvider) -> String {
        KeyStore.dir + "/llm_\(p.id).key"
    }

    private static func legacyKeyPaths(for p: LLMProvider) -> [String] {
        var paths = [keyPath(p)]
        if p.id == "deepseek" {
            paths.append(KeyStore.dir + "/deepseek.key")
        }
        return paths
    }

    static func savedKeyFile(for p: LLMProvider) -> String {
        let account = "llm:\(p.id)"
        if let value = SecureCredentialStore.shared.read(account: "llm:" + p.id) {
            return value
        }
        return SecureCredentialStore.shared.migrateLegacyKey(
            account: account,
            legacyPaths: legacyKeyPaths(for: p)
        ) ?? ""
    }

    static func key(for p: LLMProvider) -> String? {
        let saved = savedKeyFile(for: p)
        if !saved.isEmpty { return saved }
        return ShellEnv.value(p.envKey)
    }

    static func saveKey(_ key: String, for p: LLMProvider) {
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = "llm:\(p.id)"
        if t.isEmpty {
            _ = SecureCredentialStore.shared.delete(account: account)
            for path in legacyKeyPaths(for: p) {
                try? FileManager.default.removeItem(atPath: path)
            }
            return
        }
        _ = SecureCredentialStore.shared.write(t, account: account)
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
