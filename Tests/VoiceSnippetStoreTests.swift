import Foundation

@main
struct VoiceSnippetStoreTests {
    enum TestError: Error { case failed(String) }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-snippet-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = VoiceSnippetStore(directoryURL: dir)
        let original = VoiceSnippetDocument(snippets: [
            VoiceSnippet(trigger: "signature", expansion: "Best regards", isEnabled: true),
            VoiceSnippet(trigger: "disabled", expansion: "No", isEnabled: false)
        ])
        try store.save(original)
        let loaded = try store.load()

        try expect(loaded == original, "snippet document must round-trip through JSON storage")
        try expect(store.documentURL.lastPathComponent == "snippets-v1.json",
                   "snippet store must use the versioned snippets-v1.json filename")
        print("VoiceSnippetStoreTests: PASS")
    }
}
