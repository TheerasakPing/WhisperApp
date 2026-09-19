import Foundation

enum VoiceCommandProcessor {
    static let correctionPromptInstructions = """
    The speaker may self-correct while dictating with cues such as "ไม่ใช่", "แก้เป็น", or "I mean".
    When such a cue remains in the transcript, remove only the rejected wording, keep the correction,
    and preserve the surrounding context. Do not treat ordinary negation as a command unless it is
    clearly a spoken self-correction.
    """

    private static let sentenceTerminators = CharacterSet(charactersIn: ".!?。！？")
    private static let selfCorrectionCues = ["ไม่ใช่", "แก้เป็น", "i mean"]

    static func apply(to text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        result = resolveSelfCorrections(in: result)
        result = applyDeletePreviousSentence(in: result)
        result = applyFormattingCommands(in: result)
        return normalizeWhitespace(result)
    }

    static func containsSelfCorrectionCue(in text: String) -> Bool {
        selfCorrectionCues.contains { cue in
            text.range(of: cue, options: [.caseInsensitive]) != nil
        }
    }

    // MARK: - Self-correction / backtracking

    private static func resolveSelfCorrections(in text: String) -> String {
        var result = text

        // A successful replacement removes one cue. Stop on an ambiguous cue rather than
        // risking deletion of user content; TextCorrectionService handles that cue semantically.
        for _ in 0..<8 {
            guard let match = firstCue(in: result) else { break }

            let left = String(result[..<match.range.lowerBound])
            let right = String(result[match.range.upperBound...])
            let split = splitCorrectionClause(right)

            guard !split.correction.isEmpty,
                  let replacedLeft = safelyReplacingPreviousPhrase(
                    in: left,
                    with: split.correction
                  ) else {
                break
            }

            result = join(replacedLeft, split.remainder)
        }
        return result
    }

    private static func firstCue(in text: String) -> (range: Range<String.Index>, cue: String)? {
        var best: (range: Range<String.Index>, cue: String)?
        for cue in selfCorrectionCues {
            guard let range = text.range(of: cue, options: [.caseInsensitive]) else { continue }
            if best == nil || range.lowerBound < best!.range.lowerBound {
                best = (range, cue)
            }
        }
        return best
    }

    private static func splitCorrectionClause(_ rawRight: String) -> (correction: String, remainder: String) {
        let right = rawRight.trimmingCharacters(in: .whitespaces)
        guard !right.isEmpty else { return ("", "") }

        var boundaries: [String.Index] = []

        if let idx = right.firstIndex(where: { ch in
            ch == "\n" || ch.unicodeScalars.allSatisfy { sentenceTerminators.contains($0) }
        }) {
            boundaries.append(idx)
        }

        let separators = [",", " แล้ว", " และ", " จากนั้น", " and then", " then"]
        for separator in separators {
            if let range = right.range(of: separator, options: [.caseInsensitive]) {
                boundaries.append(range.lowerBound)
            }
        }

        let boundary = boundaries.min()
        if let boundary {
            let correction = String(right[..<boundary])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let remainder = String(right[boundary...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (correction, remainder)
        }

        return (right.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }

    private static func safelyReplacingPreviousPhrase(in rawLeft: String, with correction: String) -> String? {
        let left = rawLeft.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = correction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty, !replacement.isEmpty else { return nil }

        // Strongest signal: the correction and rejected suffix share a meaningful anchor.
        // Examples: วันศุกร์ -> วันพฤหัส, ESP32-S3 -> ESP32-C3.
        let maxPrefix = min(replacement.count, 16)
        let replacementHasASCII = replacement.unicodeScalars.contains { $0.isASCII }
        if maxPrefix >= 2 {
            for length in stride(from: maxPrefix, through: 2, by: -1) {
                let anchor = String(replacement.prefix(length))
                let strongEnough = replacementHasASCII || anchor.unicodeScalars.count >= 3
                guard strongEnough else { continue }
                guard let range = left.range(
                    of: anchor,
                    options: [.caseInsensitive, .backwards]
                ) else { continue }

                let suffix = String(left[range.lowerBound...])
                let isNearEnd = suffix.count <= max(replacement.count + 16, 24)
                let crossesSentence = suffix.unicodeScalars.contains { sentenceTerminators.contains($0) }
                if isNearEnd && !crossesSentence {
                    return String(left[..<range.lowerBound]) + replacement
                }
            }
        }

        // English/Latin fallback: replace the immediately previous whitespace-delimited token.
        // This safely handles "meeting on Friday I mean Thursday".
        let replacementHasLatin = replacement.unicodeScalars.contains {
            CharacterSet.letters.contains($0) && $0.isASCII
        }
        if replacementHasLatin,
           let split = left.lastIndex(where: { $0.isWhitespace }) {
            let tokenStart = left.index(after: split)
            let oldToken = String(left[tokenStart...])
            let oldHasLatin = oldToken.unicodeScalars.contains {
                CharacterSet.letters.contains($0) && $0.isASCII
            }
            if oldHasLatin {
                return String(left[...split]) + replacement
            }
        }

        // Thai without a shared anchor cannot be segmented safely using Foundation alone.
        // Preserve the original cue so the LLM can resolve it with semantic context.
        return nil
    }

    // MARK: - Explicit edit commands

    private static func applyDeletePreviousSentence(in text: String) -> String {
        var result = text
        let commands = ["ลบประโยคก่อนหน้า", "delete previous sentence"]

        for _ in 0..<8 {
            guard let match = firstMatch(of: commands, in: result) else { break }
            let left = String(result[..<match.lowerBound])
            let right = String(result[match.upperBound...])
            let kept = removingPreviousSentence(from: left)
            result = join(kept, right)
        }
        return result
    }

    private static func removingPreviousSentence(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var cursor = trimmed.endIndex

        // Ignore punctuation that closes the sentence being deleted.
        while cursor > trimmed.startIndex {
            let previous = trimmed.index(before: cursor)
            let ch = trimmed[previous]
            if ch.isWhitespace {
                cursor = previous
                continue
            }
            if ch.unicodeScalars.allSatisfy({ sentenceTerminators.contains($0) }) {
                cursor = previous
                continue
            }
            break
        }

        var search = cursor
        while search > trimmed.startIndex {
            let previous = trimmed.index(before: search)
            let ch = trimmed[previous]
            if ch == "\n" || ch.unicodeScalars.allSatisfy({ sentenceTerminators.contains($0) }) {
                let keepEnd = trimmed.index(after: previous)
                return String(trimmed[..<keepEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            search = previous
        }
        return ""
    }

    // MARK: - Formatting commands

    private static func applyFormattingCommands(in text: String) -> String {
        var result = text

        let replacements: [(phrase: String, replacement: String)] = [
            ("ขึ้นย่อหน้าใหม่", "\n\n"),
            ("ย่อหน้าใหม่", "\n\n"),
            ("new paragraph", "\n\n"),
            ("ขึ้นบรรทัดใหม่", "\n"),
            ("บรรทัดใหม่", "\n"),
            ("new line", "\n"),
            ("หัวข้อย่อย", "\n• "),
            ("bullet point", "\n• "),
            ("bullet", "\n• "),
        ]

        for item in replacements {
            result = replacePhrase(
                item.phrase,
                in: result,
                with: item.replacement
            )
        }
        return result
    }

    private static func replacePhrase(_ phrase: String, in text: String, with replacement: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let isLatin = phrase.unicodeScalars.contains { $0.isASCII && CharacterSet.letters.contains($0) }
        let core = isLatin
            ? "(?i)(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
            : escaped
        let pattern = "[ \\t]*\(core)[ \\t]*"

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
    }

    // MARK: - Utilities

    private static func firstMatch(of phrases: [String], in text: String) -> Range<String.Index>? {
        var best: Range<String.Index>?
        for phrase in phrases {
            guard let range = text.range(of: phrase, options: [.caseInsensitive]) else { continue }
            if best == nil || range.lowerBound < best!.lowerBound {
                best = range
            }
        }
        return best
    }

    private static func join(_ left: String, _ right: String) -> String {
        let lhs = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = right.trimmingCharacters(in: .whitespacesAndNewlines)
        if lhs.isEmpty { return rhs }
        if rhs.isEmpty { return lhs }

        if rhs.first == "," || rhs.first == "." || rhs.first == "!" || rhs.first == "?" {
            return lhs + rhs
        }
        return lhs + " " + rhs
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: " *\\n *",
            with: "\n",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
