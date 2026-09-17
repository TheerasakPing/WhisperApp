import Foundation

enum ProviderFailureKind: String, Codable, Equatable {
    case authentication
    case rateLimited
    case timeout
    case server
    case invalidRequest
    case invalidConfiguration
    case transport
    case invalidResponse
}

struct ProviderAttemptFailure: Error, Equatable {
    let kind: ProviderFailureKind
    let statusCode: Int?
    let message: String

    init(kind: ProviderFailureKind, statusCode: Int? = nil, message: String = "") {
        self.kind = kind
        self.statusCode = statusCode
        self.message = message
    }
}

enum ProviderFallbackPolicy {
    static func normalizedChain(primaryID: String, fallbackIDs: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for raw in [primaryID] + fallbackIDs {
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            output.append(id)
        }
        return output
    }

    static func failureKind(statusCode: Int) -> ProviderFailureKind {
        switch statusCode {
        case 401, 403:
            return .authentication
        case 429:
            return .rateLimited
        case 500...599:
            return .server
        default:
            return .invalidRequest
        }
    }

    static func failureKind(urlErrorCode: URLError.Code) -> ProviderFailureKind {
        switch urlErrorCode {
        case .timedOut:
            return .timeout
        default:
            return .transport
        }
    }
}

enum ProviderFallbackRunner {
    static func run(
        providerIDs: [String],
        attempt: @escaping (_ providerID: String, _ completion: @escaping (Result<String, ProviderAttemptFailure>) -> Void) -> Void,
        completion: @escaping (Result<String, ProviderAttemptFailure>) -> Void
    ) {
        guard !providerIDs.isEmpty else {
            completion(.failure(ProviderAttemptFailure(
                kind: .invalidConfiguration,
                message: "No providers configured"
            )))
            return
        }

        func runAttempt(_ index: Int, lastFailure: ProviderAttemptFailure?) {
            guard index < providerIDs.count else {
                completion(.failure(lastFailure ?? ProviderAttemptFailure(
                    kind: .invalidConfiguration,
                    message: "No provider produced a result"
                )))
                return
            }

            let providerID = providerIDs[index]
            attempt(providerID) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure(let failure):
                    runAttempt(index + 1, lastFailure: failure)
                }
            }
        }

        runAttempt(0, lastFailure: nil)
    }
}
