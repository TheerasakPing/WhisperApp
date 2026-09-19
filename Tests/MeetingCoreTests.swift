import Foundation

@main
struct MeetingCoreTests {
    enum TestError: Error { case failed(String) }
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        try testSummaryPrompt()
        try testMarkdownExport()
        try testEmptySections()
        try testDocumentOrdering()
        print("MeetingCoreTests: PASS")
    }

    static func testSummaryPrompt() throws {
        let prompt = MeetingNotesPrompt.systemPrompt
        for phrase in ["Summary", "Decisions", "Action Items", "Open Questions"] {
            try expect(prompt.contains(phrase), "meeting prompt must request \(phrase)")
        }
        try expect(prompt.contains("Do not invent"), "meeting notes must forbid invented facts")
        try expect(prompt.contains("Return only Markdown"), "meeting notes must be Markdown-only")
    }

    static func testMarkdownExport() throws {
        let session = MeetingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 120),
            title: "Engineering Sync",
            transcript: "Discussed PM2230 logger rollout.",
            notesMarkdown: "## Summary\nRollout discussed.",
            source: .local
        )
        let md = MeetingMarkdown.export(session)
        try expect(md.contains("# Engineering Sync"), "export must include title")
        try expect(md.contains("## Meeting Notes"), "export must include notes section")
        try expect(md.contains("## Transcript"), "export must include transcript section")
        try expect(md.contains("Discussed PM2230 logger rollout."), "export must include transcript")
        try expect(md.contains("Duration: 2m"), "export must include human-readable duration")
    }

    static func testEmptySections() throws {
        let session = MeetingSession(
            title: "Untitled",
            transcript: "hello",
            notesMarkdown: nil,
            source: .cloud
        )
        let md = MeetingMarkdown.export(session)
        try expect(!md.contains("## Meeting Notes"), "missing notes must not emit empty notes heading")
        try expect(md.contains("## Transcript"), "transcript must always export")
    }

    static func testDocumentOrdering() throws {
        let older = MeetingSession(
            startedAt: Date(timeIntervalSince1970: 10),
            title: "Older", transcript: "a", source: .cloud
        )
        let newer = MeetingSession(
            startedAt: Date(timeIntervalSince1970: 20),
            title: "Newer", transcript: "b", source: .local
        )
        let sorted = MeetingPolicy.sorted([older, newer])
        try expect(sorted.map(\.title) == ["Newer", "Older"], "meetings must sort newest first")
    }
}
