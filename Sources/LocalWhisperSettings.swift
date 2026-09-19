import Foundation

final class LocalWhisperSettingsStore {
    static let shared = LocalWhisperSettingsStore()

    private let defaults: UserDefaults
    private let executableKey = "local.whisper.executable"
    private let modelKey = "local.whisper.model"
    private let preferLocalSTTKey = "local.whisper.preferLocalSTT"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var executablePath: String {
        get { defaults.string(forKey: executableKey) ?? "" }
        set {
            defaults.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: executableKey
            )
        }
    }

    var modelPath: String {
        get { defaults.string(forKey: modelKey) ?? "" }
        set {
            defaults.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: modelKey
            )
        }
    }

    var preferLocalSTT: Bool {
        get { defaults.bool(forKey: preferLocalSTTKey) }
        set { defaults.set(newValue, forKey: preferLocalSTTKey) }
    }
}
