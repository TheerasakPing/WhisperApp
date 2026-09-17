import Foundation

/// Transcribe audio via the selected cloud STT provider, automatically advancing through
/// the configured fallback chain when a provider is unavailable or a request fails.
class CloudTranscriptionService {
    private var provider: STTProvider { STTSettings.current }

    var isAvailable: Bool { STTSettings.isConfigured(provider) }

    private func langCode(_ language: String, style: STTLanguageStyle) -> String? {
        guard let lang = Languages.find(language) else { return nil }
        if lang.code == "auto" { return nil }
        return style == .iso639_3 ? lang.iso3 : lang.code
    }

    func transcribe(fileURL: URL, language: String, completion: @escaping (String?) -> Void) {
        transcribe(fileURL: fileURL, language: language, profile: nil, completion: completion)
    }

    func transcribe(fileURL: URL, language: String, profile: AppProfile?, completion: @escaping (String?) -> Void) {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(nil); return
        }

        let primaryID = profile?.sttProviderID ?? provider.id
        let chain = ProviderFallbackPolicy.normalizedChain(
            primaryID: primaryID,
            fallbackIDs: STTSettings.fallbackProviderIDs
        )
        let profileModel = profile?.sttModel?.trimmingCharacters(in: .whitespacesAndNewlines)

        ProviderFallbackRunner.run(providerIDs: chain, attempt: { [weak self] providerID, done in
            guard let self else {
                done(.failure(ProviderAttemptFailure(kind: .transport, message: "STT service released")))
                return
            }
            guard let p = STTRegistry.all.first(where: { $0.id == providerID }) else {
                done(.failure(ProviderAttemptFailure(kind: .invalidConfiguration,
                                                     message: "Unknown STT provider: \(providerID)")))
                return
            }
            let model: String
            if providerID == primaryID, let profileModel, !profileModel.isEmpty {
                model = profileModel
            } else {
                model = STTSettings.model(for: p)
            }
            self.attempt(provider: p, model: model, fileData: fileData,
                         language: language, completion: done)
        }, completion: { result in
            switch result {
            case .success(let text):
                completion(text)
            case .failure(let failure):
                print("❌ STT fallback chain exhausted [\(failure.kind.rawValue)]: \(failure.message)")
                completion(nil)
            }
        })
    }

    private func attempt(provider p: STTProvider,
                         model: String,
                         fileData: Data,
                         language: String,
                         completion: @escaping (Result<String, ProviderAttemptFailure>) -> Void) {
        guard let key = STTSettings.key(for: p) else {
            completion(.failure(ProviderAttemptFailure(
                kind: .invalidConfiguration,
                message: "No API key for \(p.name)"
            )))
            return
        }
        guard let endpoint = STTSettings.endpoint(for: p) else {
            completion(.failure(ProviderAttemptFailure(
                kind: .invalidConfiguration,
                message: "Invalid endpoint for \(p.name)"
            )))
            return
        }
        guard !model.isEmpty else {
            completion(.failure(ProviderAttemptFailure(
                kind: .invalidConfiguration,
                message: "No model configured for \(p.name)"
            )))
            return
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
                completion(.failure(ProviderAttemptFailure(
                    kind: .invalidRequest,
                    message: "Could not build \(p.name) request: \(error)"
                )))
                return
            }
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let urlError = error as? URLError {
                completion(.failure(ProviderAttemptFailure(
                    kind: ProviderFallbackPolicy.failureKind(urlErrorCode: urlError.code),
                    message: "\(p.name): \(urlError.localizedDescription)"
                )))
                return
            }
            if let error {
                completion(.failure(ProviderAttemptFailure(
                    kind: .transport,
                    message: "\(p.name): \(error.localizedDescription)"
                )))
                return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                completion(.failure(ProviderAttemptFailure(
                    kind: ProviderFallbackPolicy.failureKind(statusCode: http.statusCode),
                    statusCode: http.statusCode,
                    message: "\(p.name) HTTP \(http.statusCode): \(String(detail.prefix(300)))"
                )))
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = STTRequestBuilder.extractText(from: json, transport: p.transport) else {
                completion(.failure(ProviderAttemptFailure(
                    kind: .invalidResponse,
                    message: "\(p.name) returned an unexpected response"
                )))
                return
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                completion(.failure(ProviderAttemptFailure(
                    kind: .invalidResponse,
                    message: "\(p.name) returned an empty transcript"
                )))
                return
            }
            completion(.success(trimmed))
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
