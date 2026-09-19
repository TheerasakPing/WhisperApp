import Foundation

@main
struct LocalWhisperCoreTests {
    enum TestError: Error { case failed(String) }
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        try testExecutableCandidates()
        try testPreferredExecutableWins()
        try testPreferredModelWins()
        try testBestModelRanking()
        try testResolveReadiness()
        try testMissingComponentsReportIssues()
        print("LocalWhisperCoreTests: PASS")
    }

    static func testExecutableCandidates() throws {
        let paths = LocalWhisperResolver.candidateExecutables(preferred: nil)
        try expect(paths.contains("/opt/homebrew/bin/whisper-cli"),
                   "Apple Silicon Homebrew whisper-cli must be discovered")
        try expect(paths.contains("/opt/homebrew/opt/whisper-cpp/bin/whisper-cli"),
                   "whisper-cpp opt path must remain supported")
        try expect(paths.contains("/usr/local/bin/whisper-cli"),
                   "Intel/Homebrew compatibility path must be discovered")
    }

    static func testPreferredExecutableWins() throws {
        let custom = "/Applications/whisper-cli"
        let paths = LocalWhisperResolver.candidateExecutables(preferred: custom)
        try expect(paths.first == custom, "user-selected executable must have highest priority")
        try expect(paths.filter { $0 == custom }.count == 1,
                   "candidate executable list must be deduplicated")
    }

    static func testPreferredModelWins() throws {
        let models = [
            "/models/ggml-large-v3.bin",
            "/models/ggml-base.bin"
        ]
        let selected = LocalWhisperResolver.selectModel(
            availablePaths: models,
            preferred: "/models/ggml-base.bin"
        )
        try expect(selected == "/models/ggml-base.bin",
                   "explicit model selection must override automatic ranking")
    }

    static func testBestModelRanking() throws {
        let models = [
            "/models/ggml-base.bin",
            "/models/ggml-small.bin",
            "/models/ggml-large-v3.bin",
            "/models/ggml-medium.bin"
        ]
        try expect(
            LocalWhisperResolver.selectModel(availablePaths: models, preferred: nil)
                == "/models/ggml-large-v3.bin",
            "automatic selection must prefer the highest accuracy available model"
        )
    }

    static func testResolveReadiness() throws {
        let executable = "/opt/homebrew/bin/whisper-cli"
        let model = "/models/ggml-medium.bin"
        let existing: Set<String> = [executable, model]
        let snapshot = LocalWhisperResolver.resolve(
            preferredExecutable: executable,
            preferredModel: model,
            availableModels: [model],
            fileExists: { existing.contains($0) }
        )
        try expect(snapshot.isReady, "local Whisper must be ready when executable and model exist")
        try expect(snapshot.executablePath == executable && snapshot.modelPath == model,
                   "resolved snapshot must preserve selected executable/model")
        try expect(snapshot.issues.isEmpty, "ready snapshot must have no issues")
    }

    static func testMissingComponentsReportIssues() throws {
        let snapshot = LocalWhisperResolver.resolve(
            preferredExecutable: "/missing/whisper-cli",
            preferredModel: "/missing/model.bin",
            availableModels: [],
            fileExists: { _ in false }
        )
        try expect(!snapshot.isReady, "missing local components must not report ready")
        try expect(snapshot.issues.contains(.executableMissing),
                   "missing executable must be reported")
        try expect(snapshot.issues.contains(.modelMissing),
                   "missing model must be reported")
    }
}
