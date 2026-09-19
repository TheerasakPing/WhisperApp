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
        try testSourceLabelledTranscript()
        try testChunkPolicy()
        try testPlainTextAndJSONExport()
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

    static func testSourceLabelledTranscript() throws {
        let segments = [
            MeetingTranscriptSegment(source: .microphone, text: "I will send the report."),
            MeetingTranscriptSegment(source: .systemAudio, text: "Please send it by Friday.")
        ]
        let text = MeetingTranscript.render(segments)
        try expect(text.contains("[You] I will send the report."),
                   "microphone transcript must be labelled as You")
        try expect(text.contains("[Meeting Audio] Please send it by Friday."),
                   "system audio transcript must keep a separate source label")
    }

    static func testChunkPolicy() throws {
        let chunks = MeetingChunkPolicy.ranges(totalFrames: 16000 * 60 * 23,
                                               sampleRate: 16000,
                                               maxChunkSeconds: 600)
        try expect(chunks.count == 3, "23 minutes must split into 10m + 10m + 3m chunks")
        try expect(chunks[0].length == 16000 * 60 * 10,
                   "first chunk must be 10 minutes at 16 kHz")
        try expect(chunks[2].length == 16000 * 60 * 3,
                   "last chunk must contain the remaining duration")
    }

    static func testPlainTextAndJSONExport() throws {
        let session = MeetingSession(
            title: "Export Test",
            transcript: "[You] hello",
            notesMarkdown: "## Summary\nhello",
            source: .cloud
        )
        let text = MeetingPlainText.export(session)
        try expect(text.contains("Export Test") && text.contains("[You] hello"),
                   "plain text export must include title and transcript")

        let data = try MeetingJSON.export(session)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MeetingSession.self, from: data)
        try expect(decoded.id == session.id && decoded.transcript == session.transcript,
                   "JSON export must round-trip the meeting session")
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
