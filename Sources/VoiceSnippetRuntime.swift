#if os(macOS)
import Foundation
import AppKit

final class VoiceSnippetRuntime {
    static let shared = VoiceSnippetRuntime()

    private let store: VoiceSnippetStore

    init(store: VoiceSnippetStore = .shared) {
        self.store = store
    }

    func expand(_ text: String) -> String {
        guard let document = try? store.load(), !document.snippets.isEmpty else {
            return text
        }
        return VoiceSnippetEngine.expand(
            text,
            document: document,
            context: Self.currentContext()
        )
    }

    static func currentContext(now: Date = Date()) -> VoiceSnippetExpansionContext {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.dateFormat = "HH:mm"

        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        return VoiceSnippetExpansionContext(
            date: dateFormatter.string(from: now),
            time: timeFormatter.string(from: now),
            clipboard: clipboard
        )
    }
}
#endif
