import Foundation

final class AppProfileStore {
    let directoryURL: URL
    let documentURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.documentURL = directoryURL.appendingPathComponent("profiles-v1.json")
    }

    func load() throws -> AppProfileDocument {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return AppProfileDocument()
        }
        let data = try Data(contentsOf: documentURL)
        return try JSONDecoder().decode(AppProfileDocument.self, from: data)
    }

    func save(_ document: AppProfileDocument) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        try data.write(to: documentURL, options: .atomic)
    }

    func resolve(bundleIdentifier: String?) -> AppProfile? {
        guard let document = try? load() else { return nil }
        return AppProfileResolver.resolve(bundleIdentifier: bundleIdentifier, in: document)
    }
}

#if os(macOS)
extension AppProfileStore {
    static let shared = AppProfileStore(
        directoryURL: URL(fileURLWithPath: KeyStore.dir, isDirectory: true)
    )
}
#endif
