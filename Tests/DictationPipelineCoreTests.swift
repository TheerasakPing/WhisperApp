import Foundation

@main
struct DictationPipelineCoreTests {
    enum TestError: Error { case failed(String) }

    final class FakeTranscriber: DictationTranscribing {
        var result: String?
        var calls = 0
        var lastLanguage: String?
        init(_ result: String?) { self.result = result }
        func transcribe(fileURL: URL, language: String, completion: @escaping (String?) -> Void) {
            calls += 1
            lastLanguage = language
            completion(result)
        }
    }

    final class FakeCorrector: DictationCorrecting {
        var result: String?
        var calls = 0
        var input: String?
        init(_ result: String?) { self.result = result }
        func correct(text: String, language: String, completion: @escaping (String?) -> Void) {
            calls += 1
            input = text
            completion(result)
        }
    }

    final class FakeDictionary: DictationDictionaryApplying {
        var input: String?
        var transform: (String) -> String = { $0 }
        func apply(to text: String) -> String {
            input = text
            return transform(text)
        }
    }

    static func main() throws {
        try testStripSoundAnnotations()
        try testStripFullwidthAnnotations()
        try testWhitespaceNormalization()
        try testFinalizeRejectsEmptyText()
        try testFinalizeAppliesDictionaryLast()
        try testCloudPipelineCorrectsThenAppliesDictionary()
        try testLocalPipelineSkipsCorrectionWhenDisabled()
        try testCorrectionFailureFallsBackToCleanTranscript()
        try testVoiceCommandsRunBeforeCorrection()
        try testTranscriptionFailureCleansUpOnce()
        print("DictationPipelineCoreTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func testStripSoundAnnotations() throws {
        let input = "hello (wind noise) world [applause] *laughs*"
        let result = DictationTextProcessor.stripSoundAnnotations(input)
        try expect(result == "hello world", "ASCII sound annotations should be removed")
    }

    static func testStripFullwidthAnnotations() throws {
        let input = "สวัสดี （เสียงลม） ครับ 【เสียงรบกวน】"
        let result = DictationTextProcessor.stripSoundAnnotations(input)
        try expect(result == "สวัสดี ครับ", "fullwidth annotations should be removed")
    }

    static func testWhitespaceNormalization() throws {
        let input = "hello   (noise)    world   ,  test"
        let result = DictationTextProcessor.stripSoundAnnotations(input)
        try expect(result == "hello world, test", "annotation cleanup should normalize whitespace and punctuation spacing")
    }

    static func testFinalizeRejectsEmptyText() throws {
        do {
            _ = try DictationTextProcessor.finalize("   \n ", dictionaryApply: { $0 })
            throw TestError.failed("empty text should throw")
        } catch DictationPipelineError.emptyTranscript {
            // expected
        }
    }

    static func testFinalizeAppliesDictionaryLast() throws {
        var dictionaryInput: String?
        let result = try DictationTextProcessor.finalize("  ESP สามสอง  ") { text in
            dictionaryInput = text
            return text.replacingOccurrences(of: "ESP สามสอง", with: "ESP32")
        }
        try expect(dictionaryInput == "ESP สามสอง", "dictionary should receive trimmed text")
        try expect(result == "ESP32", "dictionary output should be the final text")
    }

    static func testCloudPipelineCorrectsThenAppliesDictionary() throws {
        let cloud = FakeTranscriber("hello (noise) wrld")
        let local = FakeTranscriber("unused")
        let corrector = FakeCorrector("hello world")
        let dictionary = FakeDictionary()
        dictionary.transform = { $0.replacingOccurrences(of: "world", with: "WORLD") }
        var removed = 0
        var events: [DictationPipelineEvent] = []
        var outcome: DictationOutcome?
        let pipeline = DictationPipeline(
            cloudTranscriber: cloud,
            localTranscriber: local,
            corrector: corrector,
            dictionary: dictionary,
            removeFile: { _ in removed += 1 }
        )
        let request = DictationRequest(
            audioURL: URL(fileURLWithPath: "/tmp/a.wav"),
            language: "en",
            source: .cloud,
            correctionEnabled: true
        )

        pipeline.process(request, onEvent: { events.append($0) }) { result in
            if case .success(let value) = result { outcome = value }
        }

        try expect(cloud.calls == 1 && local.calls == 0, "cloud request should use only cloud transcriber")
        try expect(corrector.input == "hello wrld", "correction should receive cleaned transcript")
        try expect(dictionary.input == "hello world", "dictionary should run after correction")
        try expect(outcome?.finalText == "hello WORLD", "final text should include dictionary transform")
        try expect(removed == 1, "audio should be removed exactly once")
        try expect(events.count == 3 && events[0] == .transcribing && events[1] == .correcting,
                   "pipeline event order mismatch")
    }

    static func testLocalPipelineSkipsCorrectionWhenDisabled() throws {
        let cloud = FakeTranscriber("unused")
        let local = FakeTranscriber("local text")
        let corrector = FakeCorrector("should not run")
        let dictionary = FakeDictionary()
        var outcome: DictationOutcome?
        let pipeline = DictationPipeline(
            cloudTranscriber: cloud,
            localTranscriber: local,
            corrector: corrector,
            dictionary: dictionary,
            removeFile: { _ in }
        )
        let request = DictationRequest(
            audioURL: URL(fileURLWithPath: "/tmp/b.wav"),
            language: "th",
            source: .local,
            correctionEnabled: false
        )

        pipeline.process(request, onEvent: { _ in }) { result in
            if case .success(let value) = result { outcome = value }
        }

        try expect(local.calls == 1 && cloud.calls == 0, "local request should use only local transcriber")
        try expect(local.lastLanguage == "th", "local transcriber should receive request language")
        try expect(corrector.calls == 0, "correction must be skipped when disabled")
        try expect(outcome?.finalText == "local text", "local output mismatch")
    }

    static func testCorrectionFailureFallsBackToCleanTranscript() throws {
        let cloud = FakeTranscriber("hello [noise] world")
        let local = FakeTranscriber("unused")
        let corrector = FakeCorrector(nil)
        let dictionary = FakeDictionary()
        var outcome: DictationOutcome?
        let pipeline = DictationPipeline(
            cloudTranscriber: cloud,
            localTranscriber: local,
            corrector: corrector,
            dictionary: dictionary,
            removeFile: { _ in }
        )
        let request = DictationRequest(
            audioURL: URL(fileURLWithPath: "/tmp/c.wav"),
            language: "en",
            source: .cloud,
            correctionEnabled: true
        )

        pipeline.process(request, onEvent: { _ in }) { result in
            if case .success(let value) = result { outcome = value }
        }

        try expect(outcome?.correctedText == nil, "nil correction should stay nil in outcome")
        try expect(outcome?.finalText == "hello world", "nil correction should fall back to cleaned transcript")
    }

    static func testVoiceCommandsRunBeforeCorrection() throws {
        let cloud = FakeTranscriber("hello new line world")
        let local = FakeTranscriber("unused")
        let corrector = FakeCorrector("hello\nworld")
        let dictionary = FakeDictionary()
        var outcome: DictationOutcome?
        let pipeline = DictationPipeline(
            cloudTranscriber: cloud,
            localTranscriber: local,
            corrector: corrector,
            dictionary: dictionary,
            removeFile: { _ in }
        )
        let request = DictationRequest(
            audioURL: URL(fileURLWithPath: "/tmp/voice-command.wav"),
            language: "en",
            source: .cloud,
            correctionEnabled: true
        )

        pipeline.process(request, onEvent: { _ in }) { result in
            if case .success(let value) = result { outcome = value }
        }

        try expect(corrector.input == "hello\nworld",
                   "voice commands must be applied before AI correction")
        try expect(outcome?.finalText == "hello\nworld",
                   "formatted command output must survive the pipeline")
    }

    static func testTranscriptionFailureCleansUpOnce() throws {
        let cloud = FakeTranscriber(nil)
        let local = FakeTranscriber("unused")
        let corrector = FakeCorrector(nil)
        let dictionary = FakeDictionary()
        var removed = 0
        var failure: DictationPipelineError?
        let pipeline = DictationPipeline(
            cloudTranscriber: cloud,
            localTranscriber: local,
            corrector: corrector,
            dictionary: dictionary,
            removeFile: { _ in removed += 1 }
        )
        let request = DictationRequest(
            audioURL: URL(fileURLWithPath: "/tmp/d.wav"),
            language: "auto",
            source: .cloud,
            correctionEnabled: true
        )

        pipeline.process(request, onEvent: { _ in }) { result in
            if case .failure(let error) = result { failure = error }
        }

        try expect(failure == .transcriptionFailed, "nil STT result should report transcriptionFailed")
        try expect(removed == 1, "failed transcription should remove audio exactly once")
    }
}
