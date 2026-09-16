import Foundation

/// Manages STT provider settings: selected provider + key/model/endpoint per provider.
/// Provider metadata and transport behavior live in STTProviderCore.swift.
enum STTSettings {
    private static let defaults = UserDefaults.standard
    private static let providerKey = "stt.provider"

    static var providerID: String {
        get { defaults.string(forKey: providerKey) ?? "groq" }
        set { defaults.set(newValue, forKey: providerKey) }
    }

    static var current: STTProvider { STTRegistry.provider(id: providerID) }

    private static func keyPath(_ p: STTProvider) -> String { KeyStore.dir + "/stt_\(p.id).key" }

    static func key(for p: STTProvider) -> String? {
        if let k = try? String(contentsOfFile: keyPath(p), encoding: .utf8) {
            let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        // backward-compat: ElevenLabs was previously stored at ~/.whisperapp/elevenlabs.key
        if p.id == "elevenlabs", let k = KeyStore.elevenLabsKey() { return k }
        return ShellEnv.value(p.envKey)
    }

    static func savedKeyFile(for p: STTProvider) -> String {
        if let k = try? String(contentsOfFile: keyPath(p), encoding: .utf8) {
            return k.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if p.id == "elevenlabs",
           let k = try? String(contentsOfFile: KeyStore.elevenPath, encoding: .utf8) {
            return k.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    static func saveKey(_ key: String, for p: STTProvider) {
        try? FileManager.default.createDirectory(atPath: KeyStore.dir, withIntermediateDirectories: true)
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if p.id == "elevenlabs" { KeyStore.saveElevenLabsKey(t) }
        let path = keyPath(p)
        try? t.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
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
