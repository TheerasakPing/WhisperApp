import Foundation

final class MeetingStore {
    static var shared: MeetingStore {
        MeetingStore(
            directoryURL: URL(fileURLWithPath: KeyStore.dir, isDirectory: true),
            maxSessions: 100
        )
    }

    let directoryURL: URL
    let documentURL: URL
    let maxSessions: Int

    init(directoryURL: URL, maxSessions: Int = 100) {
        self.directoryURL = directoryURL
        self.documentURL = directoryURL.appendingPathComponent("meetings-v1.json")
        self.maxSessions = max(1, maxSessions)
    }

    func load() throws -> MeetingDocument {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return MeetingDocument()
        }
        let data = try Data(contentsOf: documentURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var doc = try decoder.decode(MeetingDocument.self, from: data)
        doc.sessions = Array(MeetingPolicy.sorted(doc.sessions).prefix(maxSessions))
        return doc
    }

    func upsert(_ session: MeetingSession) throws {
        var doc = (try? load()) ?? MeetingDocument()
        if let idx = doc.sessions.firstIndex(where: { $0.id == session.id }) {
            doc.sessions[idx] = session
        } else {
            doc.sessions.append(session)
        }
        doc.sessions = Array(MeetingPolicy.sorted(doc.sessions).prefix(maxSessions))
        try save(doc)
    }

    func delete(id: UUID) throws {
        var doc = (try? load()) ?? MeetingDocument()
        doc.sessions.removeAll { $0.id == id }
        try save(doc)
    }

    func clear() throws {
        try save(MeetingDocument())
    }

    private func save(_ doc: MeetingDocument) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(doc).write(to: documentURL, options: .atomic)
    }
}
