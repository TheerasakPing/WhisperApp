import Foundation
import AppKit
import Combine
import Carbon.HIToolbox
import ApplicationServices

/// Visual processing stage — drives the floating status overlay
enum Stage: Equatable {
    case idle
    case recording
    case transcribing
    case correcting
    case done(String)
    case error(String)
}

/// Owns recording/UI state while DictationPipeline owns transcription, correction,
/// transcript cleanup, dictionary application, and temporary-audio lifetime.
class DictationController: ObservableObject {
    @Published var isRecording = false
    @Published var status = ""
    @Published var stage: Stage = .idle
    @Published var useCloudSTT = true
    @Published var useCorrection = true
    @Published var language = "th"

    let recorder = AudioRecorder()
    private let pipeline = DictationPipeline()
    private var processing = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        recorder.$recordedFileURL
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in self?.handleAudio(url) }
            .store(in: &cancellables)
    }

    func toggle() { recorder.isRecording ? stop() : start() }

    func start() {
        guard !processing, !recorder.isRecording else { return }
        recorder.startRecording()
        isRecording = recorder.isRecording
        if isRecording {
            status = "Listening…"
            stage = .recording
        } else {
            status = "❌ Microphone unavailable"
            stage = .error("Microphone unavailable")
        }
    }

    func stop() {
        guard recorder.isRecording else { return }
        recorder.stopRecording()
        isRecording = false
        status = "⏳ Processing…"
        stage = .transcribing
    }

    func pasteLastTranscript() {
        do {
            guard let record = try HistoryStore.shared.latest() else {
                status = "History is empty"
                return
            }
            Paster.paste(record.finalText)
            status = "✅ Pasted last transcript"
        } catch {
            status = "⚠️ Could not load history"
        }
    }

    func undoLastPaste() {
        Paster.undo()
        status = "↩️ Undo sent"
    }

    private func handleAudio(_ url: URL) {
        processing = true
        let request = DictationRequest(
            audioURL: url,
            language: language,
            source: useCloudSTT ? .cloud : .local,
            correctionEnabled: useCorrection
        )

        pipeline.process(
            request,
            onEvent: { [weak self] event in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch event {
                    case .transcribing:
                        self.status = request.source == .cloud ? "☁️ Transcribing…" : "📝 Transcribing…"
                        self.stage = .transcribing
                    case .correcting:
                        self.status = "✨ AI correction…"
                        self.stage = .correcting
                    case .completed, .failed:
                        // Terminal UI is driven from the Result below so success/error handling stays in one place.
                        break
                    }
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch result {
                    case .success(let outcome):
                        let final = outcome.finalText
                        let snippet = String(final.prefix(28))
                        self.status = "✅ " + snippet
                        self.stage = .done(snippet)
                        self.processing = false

                        let historySource: HistorySource = request.source == .cloud ? .cloud : .local
                        let record = HistoryRecord(
                            rawTranscript: outcome.rawTranscript,
                            correctedText: outcome.correctedText,
                            finalText: final,
                            language: request.language,
                            source: historySource,
                            correctionEnabled: request.correctionEnabled
                        )
                        // History is best-effort and must never block dictation or paste.
                        _ = try? HistoryStore.shared.append(record)
                        Paster.paste(final)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                            guard let self else { return }
                            if self.stage == .done(snippet) { self.stage = .idle }
                        }

                    case .failure:
                        let message = "No audio detected"
                        self.status = "⚠️ \(message)"
                        self.stage = .error(message)
                        self.processing = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            if self?.stage == .error(message) { self?.stage = .idle }
                        }
                    }
                }
            }
        )
    }
}

/// Clipboard and keyboard actions used by dictation/history (requires Accessibility for synthetic keys).
enum Paster {
    private static var didPrompt = false

    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    static func paste(_ text: String) {
        copy(text)

        // ไม่มีสิทธิ์ Accessibility → เก็บใน clipboard เงียบๆ ผู้ใช้กด ⌘V เอง
        // (ห้ามเด้ง dialog ตรงนี้ จะวนระหว่าง transcribe ไม่หยุด)
        guard AXIsProcessTrusted() else { return }
        postCommandKey(CGKeyCode(kVK_ANSI_V))
    }

    static func undo() {
        guard AXIsProcessTrusted() else { return }
        postCommandKey(CGKeyCode(kVK_ANSI_Z), delay: 0.10)
    }

    private static func postCommandKey(_ keyCode: CGKeyCode, delay: TimeInterval = 0.05) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
            down?.flags = .maskCommand
            let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    /// ถามสิทธิ์ Accessibility แค่ครั้งเดียวต่อ session (เรียกตอนเปิดแอป)
    static func promptAccessibilityOnce() {
        guard !didPrompt, !AXIsProcessTrusted() else { return }
        didPrompt = true
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
