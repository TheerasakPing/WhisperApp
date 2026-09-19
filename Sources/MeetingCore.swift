import Foundation

enum MeetingTranscriptionSource: String, Codable, CaseIterable, Identifiable {
    case cloud
    case local

    var id: String { rawValue }
    var title: String { self == .cloud ? "Cloud STT" : "Local Whisper" }
}

enum MeetingAudioSource: String, Codable, CaseIterable, Identifiable {
    case microphone
    case microphoneAndSystemAudio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone: return "Microphone only"
        case .microphoneAndSystemAudio: return "Microphone + System Audio"
        }
    }
}

enum MeetingTranscriptSource: String, Codable {
    case microphone
    case systemAudio

    var label: String {
        switch self {
        case .microphone: return "You"
        case .systemAudio: return "Meeting Audio"
        }
    }
}

struct MeetingTranscriptSegment: Codable, Equatable, Identifiable {
    let id: UUID
    let source: MeetingTranscriptSource
    let text: String

    init(id: UUID = UUID(), source: MeetingTranscriptSource, text: String) {
        self.id = id
        self.source = source
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MeetingTranscript {
    static func render(_ segments: [MeetingTranscriptSegment]) -> String {
        segments
            .filter { !$0.text.isEmpty }
            .map { "[\($0.source.label)] \($0.text)" }
            .joined(separator: "\n\n")
    }
}

struct MeetingChunkRange: Equatable {
    let startFrame: Int64
    let length: Int64
}

enum MeetingChunkPolicy {
    static func ranges(
        totalFrames: Int64,
        sampleRate: Double,
        maxChunkSeconds: Double = 600
    ) -> [MeetingChunkRange] {
        guard totalFrames > 0, sampleRate > 0, maxChunkSeconds > 0 else { return [] }
        let maxFrames = max(Int64(sampleRate * maxChunkSeconds), 1)
        var result: [MeetingChunkRange] = []
        var cursor: Int64 = 0
        while cursor < totalFrames {
            let remaining = totalFrames - cursor
            let length = min(maxFrames, remaining)
            result.append(MeetingChunkRange(startFrame: cursor, length: length))
            cursor += length
        }
        return result
    }
}

struct MeetingSession: Identifiable, Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var title: String
    var transcript: String
    var notesMarkdown: String?
    var source: MeetingTranscriptionSource
    var audioSource: MeetingAudioSource

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        title: String,
        transcript: String,
        notesMarkdown: String? = nil,
        source: MeetingTranscriptionSource,
        audioSource: MeetingAudioSource = .microphone
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Meeting" : title
        self.transcript = transcript
        self.notesMarkdown = notesMarkdown
        self.source = source
        self.audioSource = audioSource
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(startedAt))
    }
}

struct MeetingDocument: Codable, Equatable {
    var schemaVersion: Int = 1
    var sessions: [MeetingSession] = []
}

enum MeetingPolicy {
    static func sorted(_ sessions: [MeetingSession]) -> [MeetingSession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    static func durationString(_ duration: TimeInterval?) -> String {
        guard let duration else { return "In progress" }
        let seconds = max(Int(duration.rounded()), 0)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remaining = seconds % 60
        if remaining == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remaining)s"
    }
}

enum MeetingNotesPrompt {
    static let systemPrompt = """
    You create accurate meeting notes from a verbatim transcript.
    Return only Markdown with these headings, in this exact order:
    ## Summary
    ## Decisions
    ## Action Items
    ## Open Questions

    Preserve names, dates, numbers, model identifiers, technical terms, and explicit owners/deadlines.
    Do not invent facts, decisions, owners, deadlines, or questions that are not supported by the transcript.
    If a section has no supported content, write "- None recorded".
    Return only Markdown. Do not add commentary outside the requested headings.
    """
}

enum MeetingMarkdown {
    static func export(_ session: MeetingSession) -> String {
        var lines: [String] = [
            "# \(session.title)",
            "",
            "Started: \(iso.string(from: session.startedAt))",
            "Duration: \(MeetingPolicy.durationString(session.duration))",
            "STT: \(session.source.title)",
            "Audio: \(session.audioSource.title)",
        ]

        if let notes = session.notesMarkdown?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            lines += ["", "## Meeting Notes", "", notes]
        }

        lines += ["", "## Transcript", "", session.transcript]
        return lines.joined(separator: "\n")
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

enum MeetingPlainText {
    static func export(_ session: MeetingSession) -> String {
        var values = [
            session.title,
            "Started: \(session.startedAt)",
            "Duration: \(MeetingPolicy.durationString(session.duration))",
            "",
        ]
        if let notes = session.notesMarkdown, !notes.isEmpty {
            values += ["MEETING NOTES", notes, ""]
        }
        values += ["TRANSCRIPT", session.transcript]
        return values.joined(separator: "\n")
    }
}

enum MeetingJSON {
    static func export(_ session: MeetingSession) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(session)
    }
}
