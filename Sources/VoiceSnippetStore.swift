import Foundation

final class VoiceSnippetStore {
    let directoryURL: URL
    let documentURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.documentURL = directoryURL.appendingPathComponent("snippets-v1.json")
    }

    func load() throws -> VoiceSnippetDocument {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return VoiceSnippetDocument()
        }
        let data = try Data(contentsOf: documentURL)
        return try JSONDecoder().decode(VoiceSnippetDocument.self, from: data)
    }

    func save(_ document: VoiceSnippetDocument) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(document).write(to: documentURL, options: .atomic)
    }
}

#if os(macOS)
extension VoiceSnippetStore {
    static var shared: VoiceSnippetStore {
        VoiceSnippetStore(
            directoryURL: URL(fileURLWithPath: KeyStore.dir, isDirectory: true)
        )
    }
}
#endif
