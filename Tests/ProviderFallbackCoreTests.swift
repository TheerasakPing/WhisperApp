import Foundation

@main
struct ProviderFallbackCoreTests {
    enum TestError: Error { case failed(String) }

    static func main() throws {
        try testNormalizedChainKeepsPrimaryFirstAndDeduplicates()
        try testRunnerStopsAtFirstSuccess()
        try testRunnerExhaustsInOrder()
        try testHTTPFailureClassification()
        try testURLErrorClassification()
        print("ProviderFallbackCoreTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func testNormalizedChainKeepsPrimaryFirstAndDeduplicates() throws {
        let chain = ProviderFallbackPolicy.normalizedChain(
            primaryID: "groq",
            fallbackIDs: ["openai", "groq", "", "qwen_asr", "openai"]
        )
        try expect(chain == ["groq", "openai", "qwen_asr"],
                   "chain must keep primary first, remove blanks and deduplicate")
    }

    static func testRunnerStopsAtFirstSuccess() throws {
        var attempts: [String] = []
        var output: String?
        ProviderFallbackRunner.run(providerIDs: ["groq", "openai", "zai"], attempt: { id, done in
            attempts.append(id)
            if id == "openai" {
                done(.success("ok"))
            } else {
                done(.failure(ProviderAttemptFailure(kind: .rateLimited, message: id)))
            }
        }, completion: { result in
            if case .success(let value) = result { output = value }
        })

        try expect(attempts == ["groq", "openai"], "runner must stop after first success")
        try expect(output == "ok", "runner must return successful output")
    }

    static func testRunnerExhaustsInOrder() throws {
        var attempts: [String] = []
        var failure: ProviderAttemptFailure?
        ProviderFallbackRunner.run(providerIDs: ["a", "b", "c"], attempt: { id, done in
            attempts.append(id)
            done(.failure(ProviderAttemptFailure(kind: .server, message: id)))
        }, completion: { result in
            if case .failure(let error) = result { failure = error }
        })

        try expect(attempts == ["a", "b", "c"], "runner must exhaust providers in order")
        try expect(failure?.message == "c", "runner must surface final failure")
    }

    static func testHTTPFailureClassification() throws {
        try expect(ProviderFallbackPolicy.failureKind(statusCode: 401) == .authentication,
                   "401 should classify as authentication")
        try expect(ProviderFallbackPolicy.failureKind(statusCode: 429) == .rateLimited,
                   "429 should classify as rate limited")
        try expect(ProviderFallbackPolicy.failureKind(statusCode: 503) == .server,
                   "5xx should classify as server")
        try expect(ProviderFallbackPolicy.failureKind(statusCode: 400) == .invalidRequest,
                   "other 4xx should classify as invalid request")
    }

    static func testURLErrorClassification() throws {
        try expect(ProviderFallbackPolicy.failureKind(urlErrorCode: .timedOut) == .timeout,
                   "timedOut should classify as timeout")
        try expect(ProviderFallbackPolicy.failureKind(urlErrorCode: .notConnectedToInternet) == .transport,
                   "network failures should classify as transport")
    }
}
