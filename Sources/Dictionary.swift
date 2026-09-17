import Foundation

/// User-maintained find→replace dictionary for words the STT keeps mis-transcribing.
/// Dictionary V2 is the authoritative metadata store; dictionary.txt remains the
/// compatibility projection for older builds and global-only use.
final class CorrectionDictionary {
    static let shared = CorrectionDictionary()

    private struct Rule { let from: String; let to: String; let isASCII: Bool }

    private static var path: String { KeyStore.dir + "/dictionary.txt" }

    private var rules: [Rule] = []
    private var lastMtime: Date? = nil
    private let lock = NSLock()

    private init() { reload(force: true) }

    // MARK: - Loading (reloads only when the legacy projection mtime changes)

    private func reload(force: Bool) {
        let path = Self.path
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let mtime = attrs?[.modificationDate] as? Date
        if !force, mtime == lastMtime { return }
        lastMtime = mtime

        let raw = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        rules = Self.parse(raw)
    }

    private static func parse(_ raw: String) -> [Rule] {
        var out: [Rule] = []
        out.reserveCapacity(64)
        for line in raw.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let arrow = trimmed.range(of: "->") else { continue }
            let from = String(trimmed[..<arrow.lowerBound]).trimmingCharacters(in: .whitespaces)
            let to   = String(trimmed[arrow.upperBound...]).trimmingCharacters(in: .whitespaces)
            if from.isEmpty || to.isEmpty { continue }
            out.append(makeRule(from: from, to: to))
        }
        return out
    }

    private static func makeRule(from: String, to: String) -> Rule {
        Rule(
            from: from,
            to: to,
            isASCII: from.unicodeScalars.allSatisfy { $0.isASCII }
        )
    }

    private func snapshot() -> [Rule] {
        lock.lock(); reload(force: false); let r = rules; lock.unlock()
        return r
    }

    private func v2Rules(bundleIdentifier: String?) -> [Rule]? {
        guard let document = try? DictionaryV2Store.shared.load() else { return nil }
        return DictionaryV2Codec.activeRules(document, bundleIdentifier: bundleIdentifier)
            .map { Self.makeRule(from: $0.from, to: $0.to) }
    }

    private func applying(_ active: [Rule], to text: String) -> String {
        guard !active.isEmpty else { return text }
        var result = text
        for r in active {
            if r.isASCII {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: r.from) + "\\b"
                guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                let range = NSRange(result.startIndex..., in: result)
                let template = NSRegularExpression.escapedTemplate(for: r.to)
                result = re.stringByReplacingMatches(in: result, range: range, withTemplate: template)
            } else {
                result = result.replacingOccurrences(of: r.from, with: r.to)
            }
        }
        return result
    }

    // MARK: - Public

    /// Global compatibility path used by older callers.
    func apply(to text: String) -> String {
        applying(v2Rules(bundleIdentifier: nil) ?? snapshot(), to: text)
    }

    /// App-aware final replacement. Global rules always apply; app-scoped rules are added
    /// only when their bundle identifier matches the foreground app captured for this dictation.
    func apply(to text: String, bundleIdentifier: String?) -> String {
        applying(v2Rules(bundleIdentifier: bundleIdentifier) ?? snapshot(), to: text)
    }

    var hintForPrompt: String {
        hintForPrompt(bundleIdentifier: nil)
    }

    func hintForPrompt(bundleIdentifier: String?) -> String {
        let active = v2Rules(bundleIdentifier: bundleIdentifier) ?? snapshot()
        guard !active.isEmpty else { return "" }
        return active.map { "- \($0.from) → \($0.to)" }.joined(separator: "\n")
    }
}
