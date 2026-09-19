import Foundation

@main
struct LocalWhisperSettingsTests {
    enum TestError: Error { case failed(String) }
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        let suite = "WhisperApp.LocalModeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw TestError.failed("could not create isolated UserDefaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = LocalWhisperSettingsStore(defaults: defaults)
        try expect(store.executablePath.isEmpty && store.modelPath.isEmpty,
                   "local paths must default to auto-detect")
        try expect(!store.preferLocalSTT,
                   "existing users must keep cloud STT as the default")

        store.executablePath = "/custom/whisper-cli"
        store.modelPath = "/models/ggml-medium.bin"
        store.preferLocalSTT = true

        let reloaded = LocalWhisperSettingsStore(defaults: defaults)
        try expect(reloaded.executablePath == "/custom/whisper-cli",
                   "custom executable must persist")
        try expect(reloaded.modelPath == "/models/ggml-medium.bin",
                   "selected model must persist")
        try expect(reloaded.preferLocalSTT,
                   "local STT preference must persist")
        print("LocalWhisperSettingsTests: PASS")
    }
}
