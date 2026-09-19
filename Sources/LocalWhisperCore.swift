import Foundation

enum LocalWhisperIssue: String, Codable, Equatable {
    case executableMissing
    case modelMissing
}

struct LocalWhisperSnapshot: Equatable {
    let executablePath: String?
    let modelPath: String?
    let availableModels: [String]
    let issues: [LocalWhisperIssue]

    var isReady: Bool {
        executablePath != nil && modelPath != nil && issues.isEmpty
    }
}

enum LocalWhisperResolver {
    static func candidateExecutables(preferred: String?) -> [String] {
        var values: [String] = []
        if let preferred = cleaned(preferred) {
            values.append(preferred)
        }
        values.append(contentsOf: [
            "/opt/homebrew/bin/whisper-cli",
            "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
            "/usr/local/opt/whisper-cpp/bin/whisper-cli",
        ])
        return deduplicated(values)
    }

    static func selectModel(
        availablePaths: [String],
        preferred: String?
    ) -> String? {
        let supported = deduplicated(
            availablePaths.filter { path in
                let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
                return ext == "bin" || ext == "gguf"
            }
        )

        if let preferred = cleaned(preferred), supported.contains(preferred) {
            return preferred
        }

        let priorities = [
            "large-v3-turbo",
            "large-v3",
            "large",
            "medium",
            "small",
            "base",
            "tiny",
        ]
        for key in priorities {
            if let match = supported.first(where: {
                URL(fileURLWithPath: $0)
                    .lastPathComponent
                    .lowercased()
                    .contains(key)
            }) {
                return match
            }
        }
        return supported.sorted().first
    }

    static func resolve(
        preferredExecutable: String?,
        preferredModel: String?,
        availableModels: [String],
        fileExists: (String) -> Bool
    ) -> LocalWhisperSnapshot {
        let executable = candidateExecutables(preferred: preferredExecutable)
            .first(where: fileExists)

        var modelCandidates = availableModels
        if let preferredModel = cleaned(preferredModel),
           fileExists(preferredModel),
           !modelCandidates.contains(preferredModel) {
            modelCandidates.insert(preferredModel, at: 0)
        }
        let existingModels = modelCandidates.filter(fileExists)
        let model = selectModel(
            availablePaths: existingModels,
            preferred: preferredModel
        )

        var issues: [LocalWhisperIssue] = []
        if executable == nil { issues.append(.executableMissing) }
        if model == nil { issues.append(.modelMissing) }

        return LocalWhisperSnapshot(
            executablePath: executable,
            modelPath: model,
            availableModels: existingModels,
            issues: issues
        )
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
