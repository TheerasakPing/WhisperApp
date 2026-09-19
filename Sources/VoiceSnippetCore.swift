import Foundation

struct VoiceSnippet: Identifiable, Codable, Equatable {
    var id: UUID
    var trigger: String
    var expansion: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        trigger: String,
        expansion: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        self.expansion = expansion
        self.isEnabled = isEnabled
    }
}

struct VoiceSnippetDocument: Codable, Equatable {
    var schemaVersion: Int
    var snippets: [VoiceSnippet]

    init(schemaVersion: Int = 1, snippets: [VoiceSnippet] = []) {
        self.schemaVersion = schemaVersion
        self.snippets = snippets
    }
}

struct VoiceSnippetExpansionContext: Equatable {
    let date: String
    let time: String
    let clipboard: String

    init(date: String, time: String, clipboard: String) {
        self.date = date
        self.time = time
        self.clipboard = clipboard
    }
}

enum VoiceSnippetEngine {
    static let correctionPromptInstructions = """
    Preserve explicit voice snippet commands beginning with "แทรก" or "insert" exactly unchanged,
    including the snippet trigger words. Do not expand, rewrite, translate, remove, or punctuate
    inside those commands. They are expanded after correction by the app.
    """

    static func containsInvocation(in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: "(?i)(?:^|\\s)(?:แทรก|insert)[ \\t]+\\S"
        ) else { return false }
        return regex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) != nil
    }

    static func expand(
        _ text: String,
        document: VoiceSnippetDocument,
        context: VoiceSnippetExpansionContext
    ) -> String {
        var result = text
        let active = document.snippets
            .filter {
                $0.isEnabled &&
                !$0.trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !$0.expansion.isEmpty
            }
            .sorted {
                $0.trigger.count == $1.trigger.count
                    ? $0.trigger.localizedCaseInsensitiveCompare($1.trigger) == .orderedAscending
                    : $0.trigger.count > $1.trigger.count
            }

        for snippet in active {
            result = replaceInvocation(
                trigger: snippet.trigger,
                expansion: resolveVariables(in: snippet.expansion, context: context),
                in: result
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolveVariables(
        in template: String,
        context: VoiceSnippetExpansionContext
    ) -> String {
        template
            .replacingOccurrences(of: "{date}", with: context.date)
            .replacingOccurrences(of: "{time}", with: context.time)
            .replacingOccurrences(of: "{clipboard}", with: context.clipboard)
    }

    private static func replaceInvocation(
        trigger: String,
        expansion: String,
        in text: String
    ) -> String {
        let cleanTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTrigger.isEmpty else { return text }

        let escaped = NSRegularExpression.escapedPattern(for: cleanTrigger)
        let pattern = "(?i)(?<![\\p{L}\\p{N}_])(?:แทรก|insert)[ \\t]+\(escaped)(?![\\p{L}\\p{N}_])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: NSRegularExpression.escapedTemplate(for: expansion)
        )
    }
}
