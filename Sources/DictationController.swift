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

/// Copy text to clipboard and simulate ⌘V into the focused app (requires Accessibility permission)
enum Paster {
    private static var didPrompt = false

    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        // ไม่มีสิทธิ์ Accessibility → เก็บใน clipboard เงียบๆ ผู้ใช้กด ⌘V เอง
        // (ห้ามเด้ง dialog ตรงนี้ จะวนระหว่าง transcribe ไม่หยุด)
        guard AXIsProcessTrusted() else { return }

        // Small delay to ensure clipboard is set before simulating keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let v = CGKeyCode(kVK_ANSI_V)
            let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
            down?.flags = .maskCommand
            let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
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
