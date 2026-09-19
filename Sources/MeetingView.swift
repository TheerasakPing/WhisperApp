#if os(macOS)
import SwiftUI

struct MeetingView: View {
    @ObservedObject var controller: MeetingModeController

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 210, idealWidth: 230, maxWidth: 280)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    controls
                    transcriptSection
                    notesSection
                    exportSection
                }
                .padding(18)
            }
        }
        .frame(minWidth: 900, minHeight: 680)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Meetings")
                    .font(.headline)
                Spacer()
                Button {
                    controller.newMeeting()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Meeting")
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            if controller.sessions.isEmpty {
                Text("No saved meetings yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                Spacer()
            } else {
                List(controller.sessions, selection: Binding(
                    get: { controller.selectedSessionID },
                    set: { newID in
                        guard let newID,
                              let session = controller.sessions.first(where: { $0.id == newID }) else { return }
                        controller.selectSession(session)
                    }
                )) { session in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .lineLimit(1)
                        Text(session.startedAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tag(session.id)
                }

                Button(role: .destructive) {
                    controller.deleteSelected()
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .disabled(controller.selectedSessionID == nil || controller.isRecording)
                .padding(10)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Meeting Mode")
                .font(.title2.bold())
            Text("Long-form recording with source-labelled transcript, AI meeting notes, and local export.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Meeting title", text: $controller.title)
                    .textFieldStyle(.roundedBorder)
                    .disabled(controller.isRecording || controller.isProcessing)

                HStack {
                    Picker("Audio", selection: $controller.audioSource) {
                        Text("Microphone only").tag(MeetingAudioSource.microphone)
                        Text("Microphone + System Audio").tag(MeetingAudioSource.microphoneAndSystemAudio)
                    }
                    .frame(maxWidth: 330)

                    Picker("STT", selection: $controller.transcriptionSource) {
                        ForEach(MeetingTranscriptionSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .frame(maxWidth: 220)

                    Picker("Language", selection: $controller.language) {
                        Text("Thai + English (Mixed)").tag("th-en")
                        Text("Auto").tag("auto")
                        Text("Thai").tag("th")
                        Text("English").tag("en")
                    }
                    .frame(maxWidth: 220)
                }
                .disabled(controller.isRecording || controller.isProcessing)

                HStack(spacing: 10) {
                    if controller.isRecording {
                        Button(role: .destructive) {
                            controller.stopMeeting()
                        } label: {
                            Label("Stop Meeting", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            controller.startMeeting()
                        } label: {
                            Label("Start Meeting", systemImage: "record.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isProcessing)
                    }

                    if controller.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                        Text("Transcribing long recording…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Text(controller.status)
                        .font(.caption)
                        .foregroundStyle(controller.status.hasPrefix("⚠️") ? .orange : .secondary)
                        .lineLimit(2)
                }

                if controller.audioSource == .microphoneAndSystemAudio {
                    Text("System Audio uses macOS Screen Recording permission. Audio is kept only as temporary files until transcription finishes.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var transcriptSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Transcript")
                        .font(.headline)
                    Spacer()
                    Button("Save Edits") { controller.saveEdits() }
                        .disabled(controller.selectedSessionID == nil)
                }

                TextEditor(text: $controller.transcript)
                    .font(.body)
                    .frame(minHeight: 190)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )

                Text("Source labels distinguish your microphone ([You]) from captured meeting/system audio ([Meeting Audio]).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Meeting Notes")
                        .font(.headline)
                    Spacer()
                    if controller.isGeneratingNotes {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Generate Notes") {
                        controller.generateNotes()
                    }
                    .disabled(
                        controller.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        controller.isGeneratingNotes
                    )
                }

                TextEditor(text: $controller.notesMarkdown)
                    .font(.body)
                    .frame(minHeight: 170)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )

                Text("AI notes contain Summary, Decisions, Action Items, and Open Questions. The transcript stays verbatim and is not run through dictation corrections, commands, dictionary, or snippets.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var exportSection: some View {
        GroupBox {
            HStack {
                Text("Export")
                    .font(.headline)
                Spacer()
                Button("Export TXT") { controller.exportText() }
                Button("Export Markdown") { controller.exportMarkdown() }
                Button("Export JSON") { controller.exportJSON() }
            }
        }
    }
}
#endif
