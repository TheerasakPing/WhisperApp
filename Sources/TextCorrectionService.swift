import Foundation

/// Send raw transcription text to the selected LLM to fix typos, punctuation,
/// and sentence structure. Provider-specific wire details are delegated to
/// LLMRequestBuilder so this service stays vendor-neutral.
class TextCorrectionService: ObservableObject {
    @Published var isEnabled = true
    @Published var isCorrecting = false

    private var provider: LLMProvider { LLMSettings.current }
    var isAvailable: Bool { LLMSettings.isConfigured(provider) }

    func correct(text: String, language: String, completion: @escaping (String?) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(nil); return
        }

        let p = provider
        let key = LLMSettings.key(for: p)
        if p.requiresAPIKey && key == nil {
            print("❌ No key found for \(p.name) (configure in Settings or set env \(p.envKey))")
            completion(nil); return
        }
        guard let endpoint = LLMSettings.endpoint(for: p) else {
            print("❌ Invalid or missing endpoint for \(p.name)")
            completion(nil); return
        }

        let model = LLMSettings.model(for: p)
        guard !model.isEmpty else {
            print("❌ No model configured for \(p.name)")
            completion(nil); return
        }

        let langHint: String
        if language == "auto" {
            langHint = "The text may be in any language — keep the original language"
        } else if let name = Languages.find(language)?.name {
            langHint = "The text is in \(name)"
        } else {
            langHint = "The text may be in any language — keep the original language"
        }

        var systemPrompt = """
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
            systemPrompt += "\n\nThe user's own known corrections for their speech — apply these where the meaning matches:\n" + hint
        }

        let spec = LLMRequestBuilder.build(provider: p, model: model,
                                           systemPrompt: systemPrompt, userText: text)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60

        for (name, template) in spec.headers {
            let value: String
            if template.contains("{API_KEY}") {
                guard let key = key else { continue }
                value = template.replacingOccurrences(of: "{API_KEY}", with: key)
            } else {
                value = template
            }
            req.setValue(value, forHTTPHeaderField: name)
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: spec.body) else {
            completion(nil); return
        }
        req.httpBody = httpBody

        DispatchQueue.main.async { self.isCorrecting = true }
        let apiProtocol = spec.apiProtocol

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async { self?.isCorrecting = false }

            if let error = error {
                print("❌ Correction (\(p.name)) error: \(error.localizedDescription)")
                completion(nil); return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("❌ Correction (\(p.name)) HTTP \(http.statusCode): \(String(detail.prefix(500)))")
                completion(nil); return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Correction (\(p.name)): could not parse response")
                completion(nil); return
            }

            guard let raw = LLMRequestBuilder.extractText(from: json, apiProtocol: apiProtocol) else {
                print("❌ Correction (\(p.name)) unexpected response: \(json)")
                completion(nil); return
            }

            let cleaned = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            completion(cleaned.isEmpty ? nil : cleaned)
        }.resume()
    }
}
