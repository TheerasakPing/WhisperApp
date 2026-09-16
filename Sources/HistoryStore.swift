import Foundation

final class HistoryStore {
    let directoryURL: URL
    let documentURL: URL
    private let maxRecords: Int
    private let lock = NSLock()

    init(directoryURL: URL, maxRecords: Int = 1_000) {
        self.directoryURL = directoryURL
        self.documentURL = directoryURL.appendingPathComponent("history-v1.json")
        self.maxRecords = maxRecords
    }

    func load(now: Date = Date()) throws -> HistoryDocument {
        lock.lock(); defer { lock.unlock() }
        let loaded = try loadUnlocked()
        let pruned = HistoryPolicy.pruned(loaded, now: now, maxRecords: maxRecords)
        if pruned != loaded { try saveUnlocked(pruned) }
        return pruned
    }

    /// Persist exactly the supplied document. Time-based retention is intentionally
    /// applied by load/append/setRetention where the caller supplies the effective `now`.
    func save(_ document: HistoryDocument) throws {
        lock.lock(); defer { lock.unlock() }
        try saveUnlocked(document)
    }

    @discardableResult
    func append(_ record: HistoryRecord, now: Date = Date()) throws -> HistoryDocument {
        lock.lock(); defer { lock.unlock() }
        var document = try loadUnlocked()
        guard document.retention != .off else { return document }
        document.records.append(record)
        document = HistoryPolicy.pruned(document, now: now, maxRecords: maxRecords)
        try saveUnlocked(document)
        return document
    }

    @discardableResult
    func updateText(id: UUID, finalText: String) throws -> HistoryRecord? {
        lock.lock(); defer { lock.unlock() }
        var document = try loadUnlocked()
        guard let index = document.records.firstIndex(where: { $0.id == id }) else { return nil }
        document.records[index].finalText = finalText
        let updated = document.records[index]
        try saveUnlocked(document)
        return updated
    }

    func delete(id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        var document = try loadUnlocked()
        document.records.removeAll { $0.id == id }
        try saveUnlocked(document)
    }

    func clear() throws {
        lock.lock(); defer { lock.unlock() }
        var document = try loadUnlocked()
        document.records.removeAll()
        try saveUnlocked(document)
    }

    func setRetention(_ retention: HistoryRetention, now: Date = Date()) throws -> HistoryDocument {
        lock.lock(); defer { lock.unlock() }
        var document = try loadUnlocked()
        document.retention = retention
        document = HistoryPolicy.pruned(document, now: now, maxRecords: maxRecords)
        try saveUnlocked(document)
        return document
    }

    func latest(now: Date = Date()) throws -> HistoryRecord? {
        try load(now: now).records.first
    }

    private func loadUnlocked() throws -> HistoryDocument {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return HistoryDocument()
        }
        let data = try Data(contentsOf: documentURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HistoryDocument.self, from: data)
    }

    private func saveUnlocked(_ document: HistoryDocument) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        try data.write(to: documentURL, options: .atomic)
    }
}

#if os(macOS)
extension HistoryStore {
    static let shared = HistoryStore(
        directoryURL: URL(fileURLWithPath: KeyStore.dir, isDirectory: true)
    )
}
#endif
