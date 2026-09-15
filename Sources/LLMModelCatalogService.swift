import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum LLMModelCatalogError: LocalizedError {
    case unsupported
    case missingKey
    case invalidResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .unsupported: return "This provider does not expose a model catalog endpoint."
        case .missingKey: return "API key is required to load models."
        case .invalidResponse: return "Could not parse the model catalog response."
        case let .http(code, detail): return "Model catalog HTTP \(code): \(detail)"
        }
    }
}

final class LLMModelCatalogService {
    func fetch(provider: LLMProvider,
               apiKey: String?,
               completion: @escaping (Result<[String], Error>) -> Void) {
        guard let endpointString = provider.modelsEndpoint,
              let endpoint = URL(string: endpointString) else {
            completion(.failure(LLMModelCatalogError.unsupported)); return
        }
        if provider.requiresAPIKey && (apiKey?.isEmpty != false) {
            completion(.failure(LLMModelCatalogError.missingKey)); return
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "GET"
        req.timeoutInterval = 30
        switch provider.authStyle {
        case .bearer:
            req.setValue("Bearer \(apiKey!)", forHTTPHeaderField: "Authorization")
        case .anthropicKey:
            req.setValue(apiKey!, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .none:
            break
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                completion(.failure(LLMModelCatalogError.http(http.statusCode, String(detail.prefix(300)))))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(LLMModelCatalogError.invalidResponse)); return
            }
            let ids = LLMModelCatalog.modelIDs(from: json)
            guard !ids.isEmpty else {
                completion(.failure(LLMModelCatalogError.invalidResponse)); return
            }
            completion(.success(ids))
        }.resume()
    }
}
