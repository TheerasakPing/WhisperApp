import Foundation

enum DictationSource: String, Equatable {
    case cloud
    case local
}

struct DictationRequest: Equatable {
    let audioURL: URL
    let language: String
    let source: DictationSource
    let correctionEnabled: Bool
    let bundleIdentifier: String?
    let profile: AppProfile?

    init(
        audioURL: URL,
        language: String,
        source: DictationSource,
        correctionEnabled: Bool,
        bundleIdentifier: String? = nil,
        profile: AppProfile? = nil
    ) {
        self.audioURL = audioURL
        self.language = language
        self.source = source
        self.correctionEnabled = correctionEnabled
        self.bundleIdentifier = bundleIdentifier
        self.profile = profile
    }
}

struct DictationOutcome: Equatable {
    let rawTranscript: String
    let correctedText: String?
    let finalText: String
}

enum DictationPipelineError: Error, Equatable {
    case transcriptionFailed
    case emptyTranscript
}

enum DictationPipelineEvent: Equatable {
    case transcribing
    case correcting
    case completed(DictationOutcome)
    case failed(DictationPipelineError)
}

enum DictationTextProcessor {
    static func stripSoundAnnotations(_ text: String) -> String {
        var result = text
        let patterns = [
            "\\([^\\)]*\\)",
            "（[^）]*）",
            "\\[[^\\]]*\\]",
            "【[^】]*】",
            "\\*[^*]*\\*",
            "‹[^›]*›",
            "«[^»]*»",
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return result
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+([,.!?])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func finalize(
        _ text: String,
        dictionaryApply: (String) -> String
    ) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DictationPipelineError.emptyTranscript }

        let final = dictionaryApply(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else { throw DictationPipelineError.emptyTranscript }
        return final
    }
}
