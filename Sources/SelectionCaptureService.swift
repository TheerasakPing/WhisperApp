import Foundation
import AppKit
import Carbon.HIToolbox
import ApplicationServices

struct SelectionCapture {
    let text: String
    let targetApplication: NSRunningApplication?
}

final class SelectionCaptureService {
    static let shared = SelectionCaptureService()

    func captureSelectedText(
        completion: @escaping (SelectionCapture?) -> Void
    ) {
        guard AXIsProcessTrusted() else {
            completion(nil)
            return
        }

        let target = NSWorkspace.shared.frontmostApplication
        let pasteboard = NSPasteboard.general
        let beforeChangeCount = pasteboard.changeCount

        postCommandCopy()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            guard pasteboard.changeCount != beforeChangeCount,
                  let raw = pasteboard.string(forType: .string) else {
                completion(nil)
                return
            }

            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                completion(nil)
                return
            }

            completion(SelectionCapture(
                text: text,
                targetApplication: target
            ))
        }
    }

    private func postCommandCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_C),
            keyDown: true
        )
        down?.flags = .maskCommand
        let up = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_C),
            keyDown: false
        )
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
