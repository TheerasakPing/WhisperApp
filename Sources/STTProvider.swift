import Foundation

/// Manages STT provider settings: selected provider + key/model/endpoint per provider.
/// Provider metadata and transport behavior live in STTProviderCore.swift.
enum STTSettings {
    private static let defaults = UserDefaults.standard
    private static let providerKey = "stt.provider"
    private static let fallbackKey = "stt.fallback.providers"
    private static let localFallbackKey = "stt.fallback.localWhisper"

    static var providerID: String {
        get { defaults.string(forKey: providerKey) ?? "groq" }
        set { defaults.set(newValue, forKey: providerKey) }
    }

    static var fallbackProviderIDs: [String] {
        get { defaults.stringArray(forKey: fallbackKey) ?? [] }
        set { defaults.set(Array(newValue.prefix(3)), forKey: fallbackKey) }
    }

    static var fallbackToLocalWhisper: Bool {
        get { defaults.object(forKey: localFallbackKey) == nil ? false : defaults.bool(forKey: localFallbackKey) }
        set { defaults.set(newValue, forKey: localFallbackKey) }
    }

    static var current: STTProvider { STTRegistry.provider(id: providerID) }

    private static func keyPath(_ p: STTProvider) -> String { KeyStore.dir + "/stt_\(p.id).key" }

    private static func legacyKeyPaths(for p: STTProvider) -> [String] {
        var paths = [keyPath(p)]
        if p.id == "elevenlabs" {
            paths.append(KeyStore.elevenPath)
        }
        return paths
    }

    static func key(for p: STTProvider) -> String? {
        let saved = savedKeyFile(for: p)
        if !saved.isEmpty { return saved }
        return ShellEnv.value(p.envKey)
    }

    static func savedKeyFile(for p: STTProvider) -> String {
        let account = "stt:\(p.id)"
        if let value = SecureCredentialStore.shared.read(account: "stt:" + p.id) {
            return value
        }
        return SecureCredentialStore.shared.migrateLegacyKey(
            account: account,
            legacyPaths: legacyKeyPaths(for: p)
        ) ?? ""
    }

    static func saveKey(_ key: String, for p: STTProvider) {
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = "stt:\(p.id)"
        if t.isEmpty {
            _ = SecureCredentialStore.shared.delete(account: account)
            for path in legacyKeyPaths(for: p) {
                try? FileManager.default.removeItem(atPath: path)
            }
            return
        }
        _ = SecureCredentialStore.shared.write(t, account: account)
    }

    static func model(for p: STTProvider) -> String {
        let custom = defaults.string(forKey: "stt.model.\(p.id)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let m = custom, !m.isEmpty { return m }
        return p.defaultModel
    }

    static func saveModel(_ m: String, for p: STTProvider) {
        defaults.set(m.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "stt.model.\(p.id)")
    }

    static func savedModel(for p: STTProvider) -> String {
        defaults.string(forKey: "stt.model.\(p.id)") ?? ""
    }

    static func endpointString(for p: STTProvider) -> String {
        let custom = defaults.string(forKey: "stt.endpoint.\(p.id)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = custom, !e.isEmpty { return e }
        return p.defaultEndpoint
    }

    static func endpoint(for p: STTProvider) -> URL? { URL(string: endpointString(for: p)) }

    static func saveEndpoint(_ e: String, for p: STTProvider) {
        defaults.set(e.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "stt.endpoint.\(p.id)")
    }

    static func savedEndpoint(for p: STTProvider) -> String {
        defaults.string(forKey: "stt.endpoint.\(p.id)") ?? ""
    }

    static func isConfigured(_ p: STTProvider) -> Bool {
        key(for: p) != nil && !model(for: p).isEmpty && !endpointString(for: p).isEmpty
    }
}
