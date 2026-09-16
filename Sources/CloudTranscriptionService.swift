import Foundation

/// Transcribe audio via the selected cloud STT provider.
/// Multipart transcription and audio-chat JSON are separate transports so vendor-specific
/// request shapes do not leak into provider-name checks.
class CloudTranscriptionService {
    private var provider: STTProvider { STTSettings.current }

    var isAvailable: Bool { STTSettings.isConfigured(provider) }

    private func langCode(_ language: String, style: STTLanguageStyle) -> String? {
        guard let lang = Languages.find(language) else { return nil }
        if lang.code == "auto" { return nil }
        return style == .iso639_3 ? lang.iso3 : lang.code
    }

    func transcribe(fileURL: URL, language: String, completion: @escaping (String?) -> Void) {
        let p = provider
        guard let key = STTSettings.key(for: p) else {
            print("❌ No key found for \(p.name) (configure in Settings or set env \(p.envKey))")
            completion(nil); return
        }
        guard let endpoint = STTSettings.endpoint(for: p) else {
            print("❌ Invalid endpoint for \(p.name)")
            completion(nil); return
        }
        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(nil); return
        }

        let model = STTSettings.model(for: p)
        guard !model.isEmpty else {
            print("❌ No model configured for \(p.name)")
            completion(nil); return
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 120

        switch p.transport {
        case .multipartTranscription:
            configureMultipartRequest(&req, provider: p, key: key, model: model,
                                      fileData: fileData, language: language)

        case .audioChatJSON:
            do {
                let appLanguage = Languages.find(language)?.code ?? language
                let spec = try STTRequestBuilder.buildJSON(provider: p,
                                                           model: model,
                                                           audioData: fileData,
                                                           mimeType: "audio/wav",
                                                           language: appLanguage)
                for (name, template) in spec.headers {
                    req.setValue(template.replacingOccurrences(of: "{API_KEY}", with: key),
                                 forHTTPHeaderField: name)
                }
                req.httpBody = try JSONSerialization.data(withJSONObject: spec.body)
            } catch {
                print("❌ Could not build \(p.name) request: \(error)")
                completion(nil); return
            }
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                print("❌ \(p.name) error: \(error.localizedDescription)")
                completion(nil); return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("❌ \(p.name) HTTP \(http.statusCode): \(String(detail.prefix(500)))")
                completion(nil); return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = STTRequestBuilder.extractText(from: json, transport: p.transport) else {
                print("❌ \(p.name) returned an unexpected response")
                completion(nil); return
            }

            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(trimmed.isEmpty ? nil : trimmed)
        }.resume()
    }

    private func configureMultipartRequest(_ req: inout URLRequest,
                                           provider p: STTProvider,
                                           key: String,
                                           model: String,
                                           fileData: Data,
                                           language: String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        switch p.authStyle {
        case .elevenLabsKey:
            req.setValue(key, forHTTPHeaderField: "xi-api-key")
        case .bearer:
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        let isElevenLabs = p.authStyle == .elevenLabsKey
        field(isElevenLabs ? "model_id" : "model", model)
        if let lang = langCode(language, style: p.languageStyle) {
            field(isElevenLabs ? "language_code" : "language", lang)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
    }
}
