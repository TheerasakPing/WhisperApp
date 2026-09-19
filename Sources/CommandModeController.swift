import Foundation
import AppKit
import Combine

enum CommandModeState: Equatable {
    case idle
    case capturing
    case ready
    case transforming(AIAction)
    case done
    case error(String)
}

final class CommandModeController: ObservableObject {
    @Published private(set) var state: CommandModeState = .idle
    @Published private(set) var selectedText = ""
    @Published private(set) var resultText = ""
    @Published private(set) var status = ""

    private let selectionService: SelectionCaptureService
    private let actionService: AIActionService
    private var targetApplication: NSRunningApplication?

    var onApplied: (() -> Void)?

    init(
        selectionService: SelectionCaptureService = .shared,
        actionService: AIActionService = AIActionService()
    ) {
        self.selectionService = selectionService
        self.actionService = actionService
    }

    func begin(completion: @escaping (Bool) -> Void) {
        guard state != .capturing else {
            completion(false)
            return
        }

        state = .capturing
        selectedText = ""
        resultText = ""
        status = "Capturing selected text…"

        selectionService.captureSelectedText { [weak self] capture in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false)
                    return
                }
                guard let capture else {
                    self.state = .error("Select text first and allow Accessibility access.")
                    self.status = "⚠️ Select text first"
                    completion(false)
                    return
                }

                self.selectedText = capture.text
                self.targetApplication = capture.targetApplication
                self.state = .ready
                self.status = "Choose an AI action"
                completion(true)
            }
        }
    }

    func apply(_ action: AIAction) {
        guard state == .ready || state == .done,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        state = .transforming(action)
        status = "✨ \(action.title)…"

        actionService.transform(text: selectedText, action: action) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let output):
                    self.resultText = output
                    self.status = "✅ \(action.title)"
                    self.state = .done

                    self.targetApplication?.activate(options: [.activateIgnoringOtherApps])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        Paster.paste(output)
                        self.onApplied?()
                    }

                case .failure(let failure):
                    self.status = "⚠️ \(failure.message.isEmpty ? "AI action failed" : failure.message)"
                    self.state = .error("AI action failed")
                }
            }
        }
    }

    func reset() {
        state = .idle
        selectedText = ""
        resultText = ""
        status = ""
        targetApplication = nil
    }
}
