#if os(macOS)
import Foundation
import AppKit
import Combine

@MainActor
final class MeetingModeController: ObservableObject {
    @Published var title = ""
    @Published var transcript = ""
    @Published var notesMarkdown = ""
    @Published var status = "Ready"
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isGeneratingNotes = false
    @Published var audioSource: MeetingAudioSource = .microphone
    @Published var transcriptionSource: MeetingTranscriptionSource = .cloud
    @Published var language = "th-en"
    @Published var sessions: [MeetingSession] = []
    @Published var selectedSessionID: UUID?

    let microphoneRecorder = AudioRecorder()
    let systemAudioRecorder = SystemAudioRecorder()

    private let transcriber = MeetingTranscriptionService()
    private let notesService = MeetingNotesService()
    private var cancellables = Set<AnyCancellable>()

    private var meetingStartedAt: Date?
    private var microphoneURL: URL?
    private var systemAudioURL: URL?
    private var awaitingStop = false
    private var systemStopCompleted = false
    private var systemCaptureStarted = false

    init() {
        microphoneRecorder.$recordedFileURL
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self, self.awaitingStop else { return }
                self.microphoneURL = url
                self.processStoppedMeetingIfReady()
            }
            .store(in: &cancellables)

        reloadSessions()
    }

    func startMeeting() {
        guard !isRecording, !isProcessing else { return }

        transcript = ""
        notesMarkdown = ""
        microphoneURL = nil
        systemAudioURL = nil
        systemStopCompleted = audioSource == .microphone
        systemCaptureStarted = false
        awaitingStop = false
        meetingStartedAt = Date()

        microphoneRecorder.startRecording()
        guard microphoneRecorder.isRecording else {
            status = "⚠️ Microphone unavailable"
            meetingStartedAt = nil
            return
        }

        isRecording = true
        status = "🔴 Recording meeting…"

        if audioSource == .microphoneAndSystemAudio {
            systemAudioRecorder.start { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.systemCaptureStarted = true
                        self.status = "🔴 Recording microphone + system audio…"
                    case .failure(let error):
                        self.systemCaptureStarted = false
                        self.systemStopCompleted = true
                        self.status = "⚠️ System audio unavailable; microphone continues · \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func stopMeeting() {
        guard isRecording else { return }
        isRecording = false
        isProcessing = true
        awaitingStop = true
        status = "⏳ Finalizing meeting audio…"

        microphoneRecorder.stopRecording()

        if audioSource == .microphoneAndSystemAudio && systemCaptureStarted {
            systemAudioRecorder.stop { [weak self] url in
                Task { @MainActor in
                    guard let self else { return }
                    self.systemAudioURL = url
                    self.systemStopCompleted = true
                    self.processStoppedMeetingIfReady()
                }
            }
        } else {
            systemStopCompleted = true
            processStoppedMeetingIfReady()
        }
    }

    func generateNotes() {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isGeneratingNotes else { return }

        isGeneratingNotes = true
        status = "✨ Generating meeting notes…"
        notesService.generate(transcript: transcript) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isGeneratingNotes = false
                switch result {
                case .success(let notes):
                    self.notesMarkdown = notes
                    self.status = "✅ Meeting notes ready"
                    self.saveEdits()
                case .failure(let error):
                    self.status = "⚠️ Notes failed: \(error.message)"
                }
            }
        }
    }

    func newMeeting() {
        guard !isRecording, !isProcessing else { return }
        selectedSessionID = nil
        title = ""
        transcript = ""
        notesMarkdown = ""
        status = "Ready"
    }

    func selectSession(_ session: MeetingSession) {
        guard !isRecording, !isProcessing else { return }
        selectedSessionID = session.id
        title = session.title
        transcript = session.transcript
        notesMarkdown = session.notesMarkdown ?? ""
        audioSource = session.audioSource
        transcriptionSource = session.source
        status = "Loaded \(session.title)"
    }

    func deleteSelected() {
        guard let id = selectedSessionID, !isRecording else { return }
        try? MeetingStore.shared.delete(id: id)
        newMeeting()
        reloadSessions()
    }

    func saveEdits() {
        guard let id = selectedSessionID,
              var session = sessions.first(where: { $0.id == id }) else { return }
        session.title = normalizedTitle()
        session.transcript = transcript
        session.notesMarkdown = notesMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : notesMarkdown
        try? MeetingStore.shared.upsert(session)
        reloadSessions(selecting: id)
    }

    func exportMarkdown() { export(format: .markdown) }
    func exportText() { export(format: .text) }
    func exportJSON() { export(format: .json) }

    private func processStoppedMeetingIfReady() {
        guard awaitingStop,
              let microphoneURL,
              systemStopCompleted else { return }

        awaitingStop = false
        status = "📝 Transcribing meeting…"

        var inputs: [(URL, MeetingTranscriptSource)] = [
            (microphoneURL, .microphone)
        ]
        if let systemAudioURL {
            inputs.append((systemAudioURL, .systemAudio))
        }

        transcribeInputs(inputs, index: 0, segments: []) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                // Original meeting audio is temporary; only transcript/notes are retained.
                try? FileManager.default.removeItem(at: microphoneURL)
                if let systemAudioURL {
                    try? FileManager.default.removeItem(at: systemAudioURL)
                }
                self.microphoneURL = nil
                self.systemAudioURL = nil
                self.isProcessing = false

                switch result {
                case .success(let segments):
                    let rendered = MeetingTranscript.render(segments)
                    self.transcript = rendered
                    let endedAt = Date()
                    let effectiveAudio: MeetingAudioSource = segments.contains(where: {
                        $0.source == .systemAudio
                    }) ? .microphoneAndSystemAudio : .microphone
                    let session = MeetingSession(
                        startedAt: self.meetingStartedAt ?? endedAt,
                        endedAt: endedAt,
                        title: self.normalizedTitle(),
                        transcript: rendered,
                        notesMarkdown: nil,
                        source: self.transcriptionSource,
                        audioSource: effectiveAudio
                    )
                    do {
                        try MeetingStore.shared.upsert(session)
                        self.selectedSessionID = session.id
                        self.reloadSessions(selecting: session.id)
                        self.status = "✅ Transcript ready"
                    } catch {
                        self.status = "⚠️ Transcript ready, but could not save meeting"
                    }
                case .failure(let error):
                    self.status = "⚠️ Meeting transcription failed: \(error.localizedDescription)"
                }
                self.meetingStartedAt = nil
            }
        }
    }

    private func transcribeInputs(
        _ inputs: [(URL, MeetingTranscriptSource)],
        index: Int,
        segments: [MeetingTranscriptSegment],
        completion: @escaping (Result<[MeetingTranscriptSegment], Error>) -> Void
    ) {
        guard index < inputs.count else {
            completion(.success(segments))
            return
        }

        let input = inputs[index]
        transcriber.transcribe(
            fileURL: input.0,
            transcriptSource: input.1,
            language: language,
            source: transcriptionSource
        ) { [weak self] result in
            guard let self else {
                completion(.failure(MeetingTranscriptionError.transcriptionFailed))
                return
            }
            switch result {
            case .success(let newSegments):
                self.transcribeInputs(
                    inputs,
                    index: index + 1,
                    segments: segments + newSegments,
                    completion: completion
                )
            case .failure(let error):
                // System audio is supplemental. Preserve the microphone transcript if it succeeds.
                if input.1 == .systemAudio && !segments.isEmpty {
                    completion(.success(segments))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    private func normalizedTitle() -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meeting \(formatter.string(from: meetingStartedAt ?? Date()))"
    }

    private func reloadSessions(selecting id: UUID? = nil) {
        sessions = (try? MeetingStore.shared.load().sessions) ?? []
        if let id {
            selectedSessionID = id
            if let session = sessions.first(where: { $0.id == id }) {
                title = session.title
                transcript = session.transcript
                notesMarkdown = session.notesMarkdown ?? ""
            }
        }
    }

    private enum ExportFormat {
        case markdown
        case text
        case json

        var extensionName: String {
            switch self {
            case .markdown: return "md"
            case .text: return "txt"
            case .json: return "json"
            }
        }
    }

    private func export(format: ExportFormat) {
        guard let session = currentSessionForExport() else {
            status = "⚠️ Nothing to export"
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sanitizedFilename(session.title) + "." + format.extensionName
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            switch format {
            case .markdown:
                try MeetingMarkdown.export(session).write(to: url, atomically: true, encoding: .utf8)
            case .text:
                try MeetingPlainText.export(session).write(to: url, atomically: true, encoding: .utf8)
            case .json:
                try MeetingJSON.export(session).write(to: url, options: .atomic)
            }
            status = "✅ Exported \(url.lastPathComponent)"
        } catch {
            status = "⚠️ Export failed: \(error.localizedDescription)"
        }
    }

    private func currentSessionForExport() -> MeetingSession? {
        if let id = selectedSessionID,
           var session = sessions.first(where: { $0.id == id }) {
            session.title = normalizedTitle()
            session.transcript = transcript
            session.notesMarkdown = notesMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : notesMarkdown
            return session
        }

        guard !transcript.isEmpty else { return nil }
        let now = Date()
        return MeetingSession(
            startedAt: meetingStartedAt ?? now,
            endedAt: now,
            title: normalizedTitle(),
            transcript: transcript,
            notesMarkdown: notesMarkdown.isEmpty ? nil : notesMarkdown,
            source: transcriptionSource,
            audioSource: audioSource
        )
    }

    private func sanitizedFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return value.components(separatedBy: invalid).joined(separator: "-")
    }
}
#endif
