import Foundation

@main
struct HistoryCoreTests {
    enum TestError: Error { case failed(String) }

    static func main() throws {
        try testRetentionPrunesExpiredRecords()
        try testHistoryOffDoesNotAppend()
        try testStoreCRUDAndLatest()
        try testStoreRoundTrip()
        try testMaximumRecordCap()
        print("HistoryCoreTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func record(_ text: String, date: Date) -> HistoryRecord {
        HistoryRecord(
            createdAt: date,
            rawTranscript: "raw \(text)",
            correctedText: "corrected \(text)",
            finalText: text,
            language: "th",
            source: .cloud,
            correctionEnabled: true
        )
    }

    static func testRetentionPrunesExpiredRecords() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let fresh = record("fresh", date: now.addingTimeInterval(-60))
        let old = record("old", date: now.addingTimeInterval(-(8 * 86_400)))
        var document = HistoryDocument(retention: .sevenDays, records: [old, fresh])
        document = HistoryPolicy.pruned(document, now: now, maxRecords: 100)
        try expect(document.records.map(\.finalText) == ["fresh"], "7-day retention should remove records older than seven days")
    }

    static func testHistoryOffDoesNotAppend() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(directoryURL: dir)
        try store.save(HistoryDocument(retention: .off))
        let result = try store.append(record("ignored", date: Date()), now: Date())
        try expect(result.records.isEmpty, "History Off must not append new records")
    }

    static func testStoreCRUDAndLatest() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(directoryURL: dir)
        try store.save(HistoryDocument(retention: .forever))

        let first = record("first", date: Date(timeIntervalSince1970: 10))
        let second = record("second", date: Date(timeIntervalSince1970: 20))
        _ = try store.append(first, now: Date(timeIntervalSince1970: 20))
        _ = try store.append(second, now: Date(timeIntervalSince1970: 20))
        try expect(try store.latest()?.id == second.id, "latest should return newest record")

        let updated = try store.updateText(id: second.id, finalText: "second edited")
        try expect(updated?.finalText == "second edited", "updateText should return updated record")
        try expect(try store.latest()?.finalText == "second edited", "updated text should persist")

        try store.delete(id: second.id)
        try expect(try store.latest()?.id == first.id, "delete should remove selected record")

        try store.clear()
        try expect(try store.load().records.isEmpty, "clear should remove all records")
    }

    static func testStoreRoundTrip() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(directoryURL: dir)
        let item = HistoryRecord(
            createdAt: Date(timeIntervalSince1970: 1234),
            rawTranscript: "raw",
            correctedText: nil,
            finalText: "final",
            language: "en",
            source: .local,
            correctionEnabled: false
        )
        try store.save(HistoryDocument(retention: .thirtyDays, records: [item]))
        let loaded = try store.load(now: Date(timeIntervalSince1970: 1234))
        try expect(loaded.retention == .thirtyDays, "retention should round-trip")
        try expect(loaded.records == [item], "history record should round-trip")
    }

    static func testMaximumRecordCap() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let records = (0..<8).map { index in
            record("r\(index)", date: now.addingTimeInterval(TimeInterval(index)))
        }
        let pruned = HistoryPolicy.pruned(
            HistoryDocument(retention: .forever, records: records),
            now: now.addingTimeInterval(10),
            maxRecords: 3
        )
        try expect(pruned.records.count == 3, "history should respect max record cap")
        try expect(pruned.records.map(\.finalText) == ["r7", "r6", "r5"], "cap should keep newest records")
    }

    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-history-tests-\(UUID().uuidString)", isDirectory: true)
    }
}
