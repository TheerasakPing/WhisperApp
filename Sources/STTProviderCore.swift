import Foundation

/// Network shape used to submit recorded audio.
enum STTTransport: String, Hashable {
    case multipartTranscription
    case audioChatJSON
}

enum STTAuthStyle: String, Hashable {
    case bearer
    case elevenLabsKey
}

enum STTLanguageStyle: String, Hashable {
    case iso639_1
    case iso639_3
}

/// Provider metadata is deliberately separate from persisted settings so new vendors can
/// be added without embedding vendor-specific checks in CloudTranscriptionService.
struct STTProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let defaultEndpoint: String
    let defaultModel: String
    let envKey: String
    let transport: STTTransport
    let authStyle: STTAuthStyle
    let languageStyle: STTLanguageStyle
    let maxAudioBytes: Int?
    let isCustom: Bool

    init(id: String,
         name: String,
         defaultEndpoint: String,
         defaultModel: String,
         envKey: String,
         transport: STTTransport,
         authStyle: STTAuthStyle = .bearer,
         languageStyle: STTLanguageStyle = .iso639_1,
         maxAudioBytes: Int? = nil,
         isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.defaultEndpoint = defaultEndpoint
        self.defaultModel = defaultModel
        self.envKey = envKey
        self.transport = transport
        self.authStyle = authStyle
        self.languageStyle = languageStyle
        self.maxAudioBytes = maxAudioBytes
        self.isCustom = isCustom
    }
}

enum STTRegistry {
    static let all: [STTProvider] = [
        STTProvider(id: "elevenlabs", name: "ElevenLabs Scribe",
                    defaultEndpoint: "https://api.elevenlabs.io/v1/speech-to-text",
                    defaultModel: "scribe_v1",
                    envKey: "ELEVENLABS_API_KEY",
                    transport: .multipartTranscription,
                    authStyle: .elevenLabsKey,
                    languageStyle: .iso639_3),
        STTProvider(id: "openai", name: "OpenAI",
                    defaultEndpoint: "https://api.openai.com/v1/audio/transcriptions",
                    defaultModel: "gpt-4o-transcribe",
                    envKey: "OPENAI_API_KEY",
                    transport: .multipartTranscription),
        STTProvider(id: "groq", name: "Groq (Whisper)",
                    defaultEndpoint: "https://api.groq.com/openai/v1/audio/transcriptions",
                    defaultModel: "whisper-large-v3-turbo",
                    envKey: "GROQ_API_KEY",
                    transport: .multipartTranscription),
        STTProvider(id: "qwen_asr", name: "Alibaba Qwen3 ASR Flash",
                    defaultEndpoint: "",
                    defaultModel: "qwen3-asr-flash",
                    envKey: "DASHSCOPE_API_KEY",
                    transport: .audioChatJSON,
                    languageStyle: .iso639_1,
                    maxAudioBytes: 10 * 1024 * 1024,
                    isCustom: true),
        STTProvider(id: "stt_custom", name: "Custom (OpenAI-compatible transcription)",
                    defaultEndpoint: "",
                    defaultModel: "",
                    envKey: "STT_API_KEY",
                    transport: .multipartTranscription,
                    isCustom: true),
    ]

    static func provider(id: String) -> STTProvider {
        all.first { $0.id == id } ?? all[0]
    }
}

struct STTJSONRequestSpec {
    let headers: [String: String]
    let body: [String: Any]
}

enum STTRequestBuilderError: Error {
    case unsupportedTransport
    case audioTooLarge(limit: Int)
}

enum STTRequestBuilder {
    static func buildJSON(provider: STTProvider,
                          model: String,
                          audioData: Data,
                          mimeType: String,
                          language: String) throws -> STTJSONRequestSpec {
        guard provider.transport == .audioChatJSON else {
            throw STTRequestBuilderError.unsupportedTransport
        }
        if let limit = provider.maxAudioBytes, audioData.count > limit {
            throw STTRequestBuilderError.audioTooLarge(limit: limit)
        }
        _ = language // Qwen3-ASR-Flash auto-detects supported languages by default.

        let dataURI = "data:\(mimeType);base64,\(audioData.base64EncodedString())"
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": [[
                    "type": "input_audio",
                    "input_audio": ["data": dataURI],
                ]],
            ]],
            "stream": false,
        ]

        var headers = ["Content-Type": "application/json"]
        switch provider.authStyle {
        case .bearer:
            headers["Authorization"] = "Bearer {API_KEY}"
        case .elevenLabsKey:
            headers["xi-api-key"] = "{API_KEY}"
        }

        return STTJSONRequestSpec(headers: headers, body: body)
    }

    static func extractText(from json: [String: Any], transport: STTTransport) -> String? {
        switch transport {
        case .multipartTranscription:
            return json["text"] as? String
        case .audioChatJSON:
            guard let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else { return nil }
            return content
        }
    }
}
