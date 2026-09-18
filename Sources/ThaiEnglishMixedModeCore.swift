import Foundation

struct ThaiEnglishProtectedText: Equatable {
    let text: String
    let terms: [String]

    func restore(in correctedText: String) -> String {
        var result = correctedText
        for (index, term) in terms.enumerated() {
            result = result.replacingOccurrences(of: "⟪\(index)⟫", with: term)
        }
        return result
    }
}

enum ThaiEnglishMixedMode {
    static let languageCode = "th-en"
    static let displayName = "Thai + English (Mixed)"

    static func isEnabled(language: String) -> Bool {
        language == languageCode
    }

    /// Mixed speech must not be pinned to one STT language. Cloud providers should auto-detect.
    static func cloudLanguageCode(language: String) -> String? {
        if language == "auto" || isEnabled(language: language) { return nil }
        return language
    }

    static func cloudLanguageCode(language: String, normalCode: String) -> String? {
        guard cloudLanguageCode(language: language) != nil else { return nil }
        return normalCode
    }

    /// whisper.cpp accepts "auto"; it does not understand the app's pseudo-code "th-en".
    static func localWhisperLanguage(language: String) -> String {
        isEnabled(language: language) ? "auto" : language
    }

    /// Hide Latin words/identifiers from the correction model and restore them afterwards.
    /// This makes mixed-mode correction deterministic for spelling/casing of terms already
    /// recognized correctly by STT (ESP32-S3, GitHub, MQTT, firmware, etc.).
    static func protectLatinTerms(in text: String) -> ThaiEnglishProtectedText {
        guard let regex = try? NSRegularExpression(
            pattern: "[A-Za-z][A-Za-z0-9._+/#:\\-]*"
        ) else {
            return ThaiEnglishProtectedText(text: text, terms: [])
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else {
            return ThaiEnglishProtectedText(text: text, terms: [])
        }

        let terms: [String] = matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }

        var protectedText = text
        for (index, match) in matches.enumerated().reversed() {
            guard let range = Range(match.range, in: protectedText) else { continue }
            protectedText.replaceSubrange(range, with: "⟪\(index)⟫")
        }

        return ThaiEnglishProtectedText(text: protectedText, terms: terms)
    }

    static func correctionInstructions(protectedTermCount: Int) -> String {
        var instructions = """
        Thai-English mixed dictation rules:
        - Preserve natural Thai-English code-switching. Do not translate Thai to English or English to Thai.
        - Keep English words, acronyms, product/model names, version strings, and code identifiers in Latin script.
        - Do not transliterate protected English/technical terms into Thai script.
        """
        if protectedTermCount > 0 {
            instructions += """

            - Tokens such as ⟪0⟫ are protected original terms. Copy every ⟪N⟫ token exactly unchanged and in place.
            """
        }
        return instructions
    }
}
