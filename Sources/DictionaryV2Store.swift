import Foundation

final class DictionaryV2Store {
    let directoryURL: URL
    let documentURL: URL
    let legacyURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.documentURL = directoryURL.appendingPathComponent("dictionary-v2.json")
        self.legacyURL = directoryURL.appendingPathComponent("dictionary.txt")
    }

    func load() throws -> DictionaryDocument {
        if FileManager.default.fileExists(atPath: documentURL.path) {
            let data = try Data(contentsOf: documentURL)
            let document = try JSONDecoder().decode(DictionaryDocument.self, from: data)
            guard document.schemaVersion == 2 else { return document }
            return document
        }

        let legacy = (try? String(contentsOf: legacyURL, encoding: .utf8)) ?? ""
        let migrated = DictionaryV2Codec.migrateLegacy(legacy)
        if !legacy.isEmpty {
            try save(migrated)
        }
        return migrated
    }

    func save(_ document: DictionaryDocument) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        try data.write(to: documentURL, options: .atomic)

        var legacy = "# Whisper Dictionary V2 compatibility projection\n"
        legacy += "# Managed by Whisper. Extra metadata lives in dictionary-v2.json.\n"
        let projected = DictionaryV2Codec.projectLegacy(document, bundleIdentifier: nil)
        if !projected.isEmpty {
            legacy += projected + "\n"
        }
        try legacy.write(to: legacyURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: legacyURL.path)
    }
}

#if os(macOS)
extension DictionaryV2Store {
    static var shared: DictionaryV2Store {
        DictionaryV2Store(directoryURL: URL(fileURLWithPath: KeyStore.dir, isDirectory: true))
    }
}
#endif
