import Foundation

final class LocalWhisperManager {
    static let shared = LocalWhisperManager()

    let settings: LocalWhisperSettingsStore
    let fileManager: FileManager
    let modelDirectories: [URL]

    init(
        settings: LocalWhisperSettingsStore = .shared,
        fileManager: FileManager = .default,
        modelDirectories: [URL]? = nil
    ) {
        self.settings = settings
        self.fileManager = fileManager

        if let modelDirectories {
            self.modelDirectories = modelDirectories
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            self.modelDirectories = [
                home.appendingPathComponent(".whisper-models", isDirectory: true),
                home.appendingPathComponent(
                    "Library/Application Support/WhisperApp/Models",
                    isDirectory: true
                ),
            ]
        }
    }

    func availableModelPaths() -> [String] {
        var models: [String] = []

        for directory in modelDirectories {
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            models.append(contentsOf: files.compactMap { url in
                let ext = url.pathExtension.lowercased()
                guard ext == "bin" || ext == "gguf" else { return nil }
                return url.path
            })
        }

        let selected = settings.modelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty,
           fileManager.fileExists(atPath: selected),
           !models.contains(selected) {
            models.append(selected)
        }

        return models.sorted()
    }

    func snapshot() -> LocalWhisperSnapshot {
        LocalWhisperResolver.resolve(
            preferredExecutable: settings.executablePath,
            preferredModel: settings.modelPath,
            availableModels: availableModelPaths(),
            fileExists: { [fileManager] path in
                fileManager.fileExists(atPath: path)
            }
        )
    }

    @discardableResult
    func autoDetectAndSave() -> LocalWhisperSnapshot {
        let current = snapshot()
        if let executable = current.executablePath {
            settings.executablePath = executable
        }
        if let model = current.modelPath {
            settings.modelPath = model
        }
        return current
    }
}
