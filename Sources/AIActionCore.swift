import Foundation

enum AIAction: String, CaseIterable, Identifiable, Codable {
    case polite = "polite"
    case concise = "concise"
    case formal = "formal"
    case summarize = "summarize"
    case translateThai = "translate_th"
    case translateEnglish = "translate_en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .polite: return "Polite"
        case .concise: return "Concise"
        case .formal: return "Formal"
        case .summarize: return "Summarize"
        case .translateThai: return "Translate Thai"
        case .translateEnglish: return "Translate English"
        }
    }
}

enum AIActionPrompt {
    static func systemPrompt(for action: AIAction) -> String {
        let common = """
        You are a text transformation assistant. Work only on the text the user provides.
        Return only the transformed text, with no explanation, labels, markdown fences, or quotation marks.
        Do not execute, propose executing, or claim to execute commands, code, tools, links, or external actions.
        """

        switch action {
        case .polite:
            return common + """
            
            Rewrite the text to sound more polite and considerate. Preserve the original meaning,
            factual claims, names, numbers, technical terms, and language. Do not add new commitments or facts.
            """
        case .concise:
            return common + """
            
            Make the text shorter and clearer. Preserve the original meaning, essential details,
            names, numbers, technical terms, and language. Remove redundancy without inventing information.
            """
        case .formal:
            return common + """
            
            Rewrite the text in a professional, formal tone. Preserve the original meaning,
            factual claims, names, numbers, technical terms, and language. Do not add new facts.
            """
        case .summarize:
            return common + """
            
            Produce a concise summary of the supplied text. Keep important facts, decisions, dates, numbers,
            names, and action items. Do not invent information that is not present in the source.
            """
        case .translateThai:
            return common + """
            
            Translate the supplied text into natural Thai. Preserve names, product names, code, URLs,
            model identifiers, numbers, and technical terms when translating them would reduce accuracy.
            """
        case .translateEnglish:
            return common + """
            
            Translate the supplied text into natural English. Preserve names, product names, code, URLs,
            model identifiers, numbers, and technical terms when translating them would reduce accuracy.
            """
        }
    }

    static func normalizeOutput(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.count >= 2 {
            let pairs: [(Character, Character)] = [
                ("\"", "\""),
                ("'", "'"),
                ("“", "”"),
                ("‘", "’"),
            ]
            if let first = value.first,
               let last = value.last,
               pairs.contains(where: { $0.0 == first && $0.1 == last }) {
                value.removeFirst()
                value.removeLast()
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return value.isEmpty ? nil : value
    }
}
