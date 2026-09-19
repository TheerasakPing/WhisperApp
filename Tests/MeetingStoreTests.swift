import Foundation

@main
struct MeetingStoreTests {
    enum TestError: Error { case failed(String) }
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-meeting-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = MeetingStore(directoryURL: dir, maxSessions: 3)
        for i in 0..<4 {
            try store.upsert(MeetingSession(
                startedAt: Date(timeIntervalSince1970: Double(i)),
                title: "Meeting \(i)",
                transcript: "Transcript \(i)",
                source: .local
            ))
        }

        let loaded = try store.load()
        try expect(loaded.sessions.count == 3, "meeting store must enforce max session retention")
        try expect(loaded.sessions.first?.title == "Meeting 3", "newest meeting must come first")
        try expect(store.documentURL.lastPathComponent == "meetings-v1.json",
                   "meeting store must use versioned local JSON")

        let updated = loaded.sessions[0]
        var changed = updated
        changed.notesMarkdown = "## Summary\nDone"
        try store.upsert(changed)
        let afterUpdate = try store.load()
        try expect(afterUpdate.sessions.first?.notesMarkdown == "## Summary\nDone",
                   "upsert must update existing meeting by id")

        try store.delete(id: changed.id)
        let afterDelete = try store.load()
        try expect(!afterDelete.sessions.contains(where: { $0.id == changed.id }),
                   "meeting deletion must persist")
        print("MeetingStoreTests: PASS")
    }
}
