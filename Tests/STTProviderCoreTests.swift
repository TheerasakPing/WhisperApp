import Foundation

@main
struct STTProviderCoreTests {
    static func main() throws {
        try testRegistryIncludesQwenASR()
        try testOpenAIMultipartProviderShape()
        try testQwenASRBuildsAudioChatPayload()
        try testQwenASRExtractsTranscript()
        print("STTProviderCoreTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw STTTestError(message) }
    }

    static func testRegistryIncludesQwenASR() throws {
        let p = STTRegistry.provider(id: "qwen_asr")
        try expect(p.id == "qwen_asr", "Qwen ASR provider missing")
        try expect(p.defaultModel == "qwen3-asr-flash", "Qwen ASR default model mismatch")
        try expect(p.transport == .audioChatJSON, "Qwen ASR must use audio-chat JSON transport")
    }

    static func testOpenAIMultipartProviderShape() throws {
        let p = STTRegistry.provider(id: "groq")
        try expect(p.transport == .multipartTranscription, "Groq should remain multipart transcription")
        try expect(p.authStyle == .bearer, "Groq should use bearer auth")
    }

    static func testQwenASRBuildsAudioChatPayload() throws {
        let p = STTRegistry.provider(id: "qwen_asr")
        let audio = Data([0x52, 0x49, 0x46, 0x46])
        let spec = try STTRequestBuilder.buildJSON(provider: p,
                                                   model: p.defaultModel,
                                                   audioData: audio,
                                                   mimeType: "audio/wav",
                                                   language: "th")
        try expect(spec.headers["Authorization"] == "Bearer {API_KEY}", "Qwen ASR bearer auth missing")
        try expect((spec.body["model"] as? String) == "qwen3-asr-flash", "Qwen ASR model missing")
        let messages = spec.body["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        let inputAudio = content?.first?["input_audio"] as? [String: Any]
        let dataURI = inputAudio?["data"] as? String
        try expect(dataURI?.hasPrefix("data:audio/wav;base64,") == true, "Qwen ASR must embed a data URI")
        try expect((spec.body["stream"] as? Bool) == false, "Qwen ASR should disable streaming")
    }

    static func testQwenASRExtractsTranscript() throws {
        let json: [String: Any] = [
            "choices": [[
                "message": ["content": "สวัสดีครับ"]
            ]]
        ]
        let text = STTRequestBuilder.extractText(from: json, transport: .audioChatJSON)
        try expect(text == "สวัสดีครับ", "Qwen ASR transcript extraction failed")
    }
}

struct STTTestError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
