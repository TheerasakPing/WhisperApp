import Foundation

final class AIActionService {
    func transform(
        text: String,
        action: AIAction,
        completion: @escaping (Result<String, ProviderAttemptFailure>) -> Void
    ) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            completion(.failure(ProviderAttemptFailure(
                kind: .invalidRequest,
                message: "No text selected"
            )))
            return
        }

        let primary = LLMSettings.current
        let chain = ProviderFallbackPolicy.normalizedChain(
            primaryID: primary.id,
            fallbackIDs: LLMSettings.fallbackProviderIDs
        )
        let systemPrompt = AIActionPrompt.systemPrompt(for: action)

        ProviderFallbackRunner.run(providerIDs: chain, attempt: { providerID, done in
            guard let provider = LLMRegistry.all.first(where: { $0.id == providerID }) else {
                done(.failure(ProviderAttemptFailure(
                    kind: .invalidConfiguration,
                    message: "Unknown LLM provider: \(providerID)"
                )))
                return
            }

            let key = LLMSettings.key(for: provider)
            if provider.requiresAPIKey && key == nil {
                done(.failure(ProviderAttemptFailure(
                    kind: .invalidConfiguration,
                    message: "No API key for \(provider.name)"
                )))
                return
            }

            guard let endpoint = LLMSettings.endpoint(for: provider) else {
                done(.failure(ProviderAttemptFailure(
                    kind: .invalidConfiguration,
                    message: "Invalid endpoint for \(provider.name)"
                )))
                return
            }

            let model = LLMSettings.model(for: provider)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty else {
                done(.failure(ProviderAttemptFailure(
                    kind: .invalidConfiguration,
                    message: "No model configured for \(provider.name)"
                )))
                return
            }

            let spec = LLMRequestBuilder.build(
                provider: provider,
                model: model,
                systemPrompt: systemPrompt,
                userText: input
            )
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 60

            for (name, template) in spec.headers {
                if template.contains("{API_KEY}") {
                    guard let key else {
                        done(.failure(ProviderAttemptFailure(
                            kind: .invalidConfiguration,
                            message: "No API key for \(provider.name)"
                        )))
                        return
                    }
                    request.setValue(
                        template.replacingOccurrences(of: "{API_KEY}", with: key),
                        forHTTPHeaderField: name
                    )
                } else {
                    request.setValue(template, forHTTPHeaderField: name)
                }
            }

            guard let body = try? JSONSerialization.data(withJSONObject: spec.body) else {
                done(.failure(ProviderAttemptFailure(
                    kind: .invalidRequest,
                    message: "Could not encode AI action request"
                )))
                return
            }
            request.httpBody = body

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let urlError = error as? URLError {
                    done(.failure(ProviderAttemptFailure(
                        kind: ProviderFallbackPolicy.failureKind(urlErrorCode: urlError.code),
                        message: "\(provider.name): \(urlError.localizedDescription)"
                    )))
                    return
                }
                if let error {
                    done(.failure(ProviderAttemptFailure(
                        kind: .transport,
                        message: "\(provider.name): \(error.localizedDescription)"
                    )))
                    return
                }
                if let http = response as? HTTPURLResponse,
                   !(200..<300).contains(http.statusCode) {
                    done(.failure(ProviderAttemptFailure(
                        kind: ProviderFallbackPolicy.failureKind(statusCode: http.statusCode),
                        statusCode: http.statusCode,
                        message: "\(provider.name) HTTP \(http.statusCode)"
                    )))
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let raw = LLMRequestBuilder.extractText(
                        from: json,
                        apiProtocol: spec.apiProtocol
                      ),
                      let output = AIActionPrompt.normalizeOutput(raw) else {
                    done(.failure(ProviderAttemptFailure(
                        kind: .invalidResponse,
                        message: "\(provider.name) returned an invalid AI action response"
                    )))
                    return
                }
                done(.success(output))
            }.resume()
        }, completion: completion)
    }
}
