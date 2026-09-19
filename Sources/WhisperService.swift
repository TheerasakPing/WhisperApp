import Foundation

class WhisperService: ObservableObject {
    @Published var language = "auto"
    @Published var statusMessage = ""

    func transcribe(fileURL: URL, completion: @escaping (String?) -> Void) {
        let local = LocalWhisperManager.shared.snapshot()
        guard let whisperPath = local.executablePath else {
            DispatchQueue.main.async {
                self.statusMessage = "❌ whisper-cli not found. Open Settings → Local M1–M4 Mode."
            }
            completion(nil)
            return
        }
        guard let modelPath = local.modelPath else {
            DispatchQueue.main.async {
                self.statusMessage = "❌ Local Whisper model not found. Open Settings → Local M1–M4 Mode."
            }
            completion(nil)
            return
        }

        DispatchQueue.main.async {
            self.statusMessage = "🔄 Transcribing locally..."
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)

        // Note: --print-colors is a boolean flag — passing "0" makes whisper treat it
        // as an input file ("error: input file not found '0'"). Skipping it entirely.
        let whisperLanguage = ThaiEnglishMixedMode.localWhisperLanguage(language: language)
        let args = [
            "-m", modelPath,
            "-f", fileURL.path,
            "-nt",                         // no timestamps
            "-l", whisperLanguage          // mixed mode maps the app pseudo-code to Whisper auto-detect
        ]

        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        process.terminationHandler = { _ in
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            if let stderr = String(data: stderrData, encoding: .utf8), !stderr.isEmpty {
                print("📋 whisper stderr: \(stderr.prefix(500))")
            }

            if let output = String(data: stdoutData, encoding: .utf8) {
                // Strip ANSI escape codes in case whisper outputs color
                let cleaned = output.replacingOccurrences(
                    of: "\u{1b}\\[[0-9;]*m",
                    with: "",
                    options: .regularExpression
                )
                let trimmed = cleaned
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty && !$0.hasPrefix("[") }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                print("📋 whisper output: '\(trimmed)'")

                DispatchQueue.main.async {
                    self.statusMessage = trimmed.isEmpty ? "⚠️ No audio detected" : "✅ Done"
                    completion(trimmed.isEmpty ? nil : trimmed)
                }
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "❌ Could not read output"
                    completion(nil)
                }
            }
        }

        do {
            try process.run()
        } catch {
            print("❌ Failed to run whisper: \(error)")
            DispatchQueue.main.async {
                self.statusMessage = "❌ Error: \(error.localizedDescription)"
            }
            completion(nil)
        }
    }
}
