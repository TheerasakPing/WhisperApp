import Foundation

/// Send raw transcription text through the selected LLM and configured fallback providers.
/// Provider-specific wire details stay in LLMRequestBuilder.
class TextCorrectionService: ObservableObject {
    @Published var isEnabled = true
    @Published var isCorrecting = false

    private var provider: LLMProvider { LLMSettings.current }
    var isAvailable: Bool { LLMSettings.isConfigured(provider) }

    func correct(text: String, language: String, completion: @escaping (String?) -> Void) {
        correct(text: text, language: language, profile: nil, completion: completion)
    }

    func correct(text: String, language: String, profile: AppProfile?, completion: @escaping (String?) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(nil); return
        }

        let primaryID = profile?.llmProviderID ?? provider.id
        let chain = ProviderFallbackPolicy.normalizedChain(
            primaryID: primaryID,
            fallbackIDs: LLMSettings.fallbackProviderIDs
        )
        let profileModel = profile?.llmModel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let systemPrompt = makeSystemPrompt(language: language, profile: profile)

        DispatchQueue.main.async { self.isCorrecting = true }
        ProviderFallbackRunner.run(providerIDs: chain, attempt: { [weak self] providerID, done in
            guard let self else {
                done(.failure(ProviderAttemptFailure(kind: .transport, message: "Correction service released")))
                return
            }
            guard let p = LLMRegistry.all.first(where: { $0.id == providerID }) else {
                done(.failure(ProviderAttemptFailure(kind: .invalidConfiguration,
                                                     message: "Unknown LLM provider: \(providerID)")))
                return
            }
            let model: String
            if providerID == primaryID, let profileModel, !profileModel.isEmpty {
                model = profileModel
            } else {
                model = LLMSettings.model(for: p)
            }
            self.attempt(provider: p, model: model, systemPrompt: systemPrompt,
                         text: text, completion: done)
        }, completion: { [weak self] result in
            DispatchQueue.main.async { self?.isCorrecting = false }
            switch result {
            case .success(let corrected):
                completion(corrected)
            case .failure(let failure):
                print("❌ LLM fallback chain exhausted [\(failure.kind.rawValue)]: \(failure.message)")
                completion(nil)
            }
        })
    }

    private func makeSystemPrompt(language: String, profile: AppProfile?) -> String {
        let langHint: String
        if language == "auto" {
            langHint = "The text may be in any language — keep the original language"
        } else if let name = Languages.find(language)?.name {
            langHint = "The text is in \(name)"
        } else {
            langHint = "The text may be in any language — keep the original language"
        }

        var prompt = """
        You are a text correction assistant for speech-to-text output, which often contains
        misheard words and missing punctuation.
        Your tasks:
        - Fix misheard/garbled words based on context
        - Add punctuation and spacing to improve readability
        - Do NOT add new content, summarize, translate, or change word endings/speaker gender
        - Return ONLY the corrected text — no explanations, no quotation marks
        \(langHint)
        """

        let hint = CorrectionDictionary.shared.hintForPrompt
        if !hint.isEmpty {
            prompt += "\n\nThe user's own known corrections for their speech — apply these where the meaning matches:\n" + hint
        }
        if let customPrompt = profile?.customPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !customPrompt.isEmpty {
            prompt += "\n\nApplication-specific instructions:\n" + customPrompt
        }
        return prompt
    }

    private func attempt(provider p: LLMProvider,
                         model: String,
                         systemPrompt: String,
                         text: String,
                         completion: @escaping (Result<String, ProviderAttemptFailure>) -> Void) {
        let key = LLMSettings.key(for: p)
        if p.requiresAPIKey && key == nil {
            completion(.failure(ProviderAttemptFailure(
                kind: .invalidConfiguration,
                message: "No API key for \(p.name)"
            )))
            return
        }
        guard let endpoint = LLMSettings.endpoint(for: p) else {
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

        let spec = LLMRequestBuilder.build(provider: p, model: model,
                                           systemPrompt: systemPrompt, userText: text)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        for (name, template) in spec.headers {
            let value: String
            if template.contains("{API_KEY}") {
                guard let key else {
                    completion(.failure(ProviderAttemptFailure(
                        kind: .invalidConfiguration,
                        message: "No API key for \(p.name)"
                    )))
                    return
                }
                value = template.replacingOccurrences(of: "{API_KEY}", with: key)
            } else {
                value = template
            }
            req.setValue(value, forHTTPHeaderField: name)
        }
        guard let httpBody = try? JSONSerialization.data(withJSONObject: spec.body) else {
            completion(.failure(ProviderAttemptFailure(
                kind: .invalidRequest,
                message: "Could not encode \(p.name) request"
            )))
            return
        }
        req.httpBody = httpBody
        let apiProtocol = spec.apiProtocol

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
                  let raw = LLMRequestBuilder.extractText(from: json, apiProtocol: apiProtocol) else {
                completion(.failure(ProviderAttemptFailure(
                    kind: .invalidResponse,
                    message: "\(p.name) returned an unexpected response"
                )))
                return
            }
            let cleaned = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !cleaned.isEmpty else {
                completion(.failure(ProviderAttemptFailure(
                    kind: .invalidResponse,
                    message: "\(p.name) returned empty correction text"
                )))
                return
            }
            completion(.success(cleaned))
        }.resume()
    }
}
