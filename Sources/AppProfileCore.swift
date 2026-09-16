import Foundation

struct AppProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var bundleIdentifiers: [String]
    var isEnabled: Bool
    var sttProviderID: String?
    var sttModel: String?
    var llmProviderID: String?
    var llmModel: String?
    var language: String?
    var customPrompt: String?

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifiers: [String],
        isEnabled: Bool = true,
        sttProviderID: String? = nil,
        sttModel: String? = nil,
        llmProviderID: String? = nil,
        llmModel: String? = nil,
        language: String? = nil,
        customPrompt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
        self.isEnabled = isEnabled
        self.sttProviderID = Self.cleaned(sttProviderID)
        self.sttModel = Self.cleaned(sttModel)
        self.llmProviderID = Self.cleaned(llmProviderID)
        self.llmModel = Self.cleaned(llmModel)
        self.language = Self.cleaned(language)
        self.customPrompt = Self.cleaned(customPrompt)
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AppProfileDocument: Codable, Equatable {
    var schemaVersion: Int
    var profiles: [AppProfile]

    init(schemaVersion: Int = 1, profiles: [AppProfile] = []) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
    }
}

enum AppProfileResolver {
    static func resolve(bundleIdentifier: String?, in document: AppProfileDocument) -> AppProfile? {
        guard let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty else {
            return nil
        }

        return document.profiles.first { profile in
            profile.isEnabled && profile.bundleIdentifiers.contains(bundleIdentifier)
        }
    }
}
