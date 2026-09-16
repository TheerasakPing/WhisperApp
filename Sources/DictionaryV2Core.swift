import Foundation

enum DictionaryScope: Codable, Equatable {
    case global
    case app(bundleIdentifier: String)
}

struct DictionaryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var spoken: String
    var preferred: String
    var aliases: [String]
    var category: String
    var scope: DictionaryScope
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        spoken: String,
        preferred: String,
        aliases: [String] = [],
        category: String = "General",
        scope: DictionaryScope = .global,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.spoken = spoken
        self.preferred = preferred
        self.aliases = aliases
        self.category = category
        self.scope = scope
        self.isEnabled = isEnabled
    }
}

struct DictionarySuggestion: Identifiable, Codable, Equatable {
    var id: UUID
    var spoken: String
    var preferred: String
    var occurrences: Int
    var isReady: Bool

    init(
        id: UUID = UUID(),
        spoken: String,
        preferred: String,
        occurrences: Int = 1,
        isReady: Bool = false
    ) {
        self.id = id
        self.spoken = spoken
        self.preferred = preferred
        self.occurrences = occurrences
        self.isReady = isReady
    }
}

struct DictionaryDocument: Codable, Equatable {
    var schemaVersion: Int
    var entries: [DictionaryEntry]
    var suggestions: [DictionarySuggestion]
    var rejectedPairs: [String]

    init(
        schemaVersion: Int = 2,
        entries: [DictionaryEntry] = [],
        suggestions: [DictionarySuggestion] = [],
        rejectedPairs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.entries = entries
        self.suggestions = suggestions
        self.rejectedPairs = rejectedPairs
    }
}

struct DictionaryRule: Equatable {
    let from: String
    let to: String
}

enum DictionaryV2Codec {
    static func migrateLegacy(_ raw: String) -> DictionaryDocument {
        var entries: [DictionaryEntry] = []
        var seen = Set<String>()

        for line in raw.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let arrow = trimmed.range(of: "->") else { continue }

            let spoken = String(trimmed[..<arrow.lowerBound]).trimmingCharacters(in: .whitespaces)
            let preferred = String(trimmed[arrow.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !spoken.isEmpty, !preferred.isEmpty else { continue }

            let key = pairKey(spoken, preferred)
            guard seen.insert(key).inserted else { continue }
            entries.append(DictionaryEntry(spoken: spoken, preferred: preferred))
        }

        return DictionaryDocument(entries: entries)
    }

    static func activeRules(_ document: DictionaryDocument, bundleIdentifier: String?) -> [DictionaryRule] {
        var rules: [DictionaryRule] = []
        var seen = Set<String>()

        for entry in document.entries where entry.isEnabled && scope(entry.scope, matches: bundleIdentifier) {
            let preferred = entry.preferred.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !preferred.isEmpty else { continue }

            let forms = [entry.spoken] + entry.aliases
            for form in forms {
                let spoken = form.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !spoken.isEmpty else { continue }
                let key = pairKey(spoken, preferred)
                guard seen.insert(key).inserted else { continue }
                rules.append(DictionaryRule(from: spoken, to: preferred))
            }
        }
        return rules
    }

    static func projectLegacy(_ document: DictionaryDocument, bundleIdentifier: String?) -> String {
        activeRules(document, bundleIdentifier: bundleIdentifier)
            .map { "\($0.from) -> \($0.to)" }
            .joined(separator: "\n")
    }

    static func pairKey(_ spoken: String, _ preferred: String) -> String {
        spoken + "\u{001F}" + preferred
    }

    private static func scope(_ scope: DictionaryScope, matches bundleIdentifier: String?) -> Bool {
        switch scope {
        case .global:
            return true
        case .app(let required):
            return bundleIdentifier == required
        }
    }
}

enum DictionaryLearningError: Error, Equatable {
    case suggestionNotFound
}

enum DictionaryLearningEngine {
    static func recordCorrection(
        original: String,
        corrected: String,
        in document: inout DictionaryDocument,
        threshold: Int = 2
    ) {
        guard let change = changedSpan(original: original, corrected: corrected) else { return }
        let key = DictionaryV2Codec.pairKey(change.spoken, change.preferred)
        guard !document.rejectedPairs.contains(key) else { return }

        let alreadyKnown = document.entries.contains { entry in
            guard entry.preferred == change.preferred else { return false }
            return entry.spoken == change.spoken || entry.aliases.contains(change.spoken)
        }
        guard !alreadyKnown else { return }

        if let index = document.suggestions.firstIndex(where: {
            $0.spoken == change.spoken && $0.preferred == change.preferred
        }) {
            document.suggestions[index].occurrences += 1
            document.suggestions[index].isReady = document.suggestions[index].occurrences >= max(1, threshold)
        } else {
            document.suggestions.append(DictionarySuggestion(
                spoken: change.spoken,
                preferred: change.preferred,
                occurrences: 1,
                isReady: threshold <= 1
            ))
        }
    }

    static func acceptSuggestion(
        _ id: UUID,
        category: String = "Learned",
        scope: DictionaryScope = .global,
        in document: inout DictionaryDocument
    ) throws {
        guard let index = document.suggestions.firstIndex(where: { $0.id == id }) else {
            throw DictionaryLearningError.suggestionNotFound
        }
        let suggestion = document.suggestions[index]
        if !document.entries.contains(where: {
            $0.spoken == suggestion.spoken && $0.preferred == suggestion.preferred
        }) {
            document.entries.append(DictionaryEntry(
                spoken: suggestion.spoken,
                preferred: suggestion.preferred,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Learned" : category,
                scope: scope,
                isEnabled: true
            ))
        }
        document.suggestions.remove(at: index)
    }

    static func rejectSuggestion(_ id: UUID, in document: inout DictionaryDocument) {
        guard let index = document.suggestions.firstIndex(where: { $0.id == id }) else { return }
        let suggestion = document.suggestions.remove(at: index)
        let key = DictionaryV2Codec.pairKey(suggestion.spoken, suggestion.preferred)
        if !document.rejectedPairs.contains(key) {
            document.rejectedPairs.append(key)
        }
    }

    private static func changedSpan(original: String, corrected: String) -> (spoken: String, preferred: String)? {
        let old = Array(original)
        let new = Array(corrected)
        guard old != new else { return nil }

        var prefix = 0
        let prefixLimit = min(old.count, new.count)
        while prefix < prefixLimit, old[prefix] == new[prefix] {
            prefix += 1
        }

        var oldEnd = old.count
        var newEnd = new.count
        while oldEnd > prefix, newEnd > prefix, old[oldEnd - 1] == new[newEnd - 1] {
            oldEnd -= 1
            newEnd -= 1
        }

        let spoken = String(old[prefix..<oldEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        let preferred = String(new[prefix..<newEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !preferred.isEmpty, spoken != preferred else { return nil }
        guard spoken.count <= 120, preferred.count <= 120 else { return nil }
        return (spoken, preferred)
    }
}
