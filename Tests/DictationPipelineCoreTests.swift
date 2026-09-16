import Foundation

@main
struct DictationPipelineCoreTests {
    enum TestError: Error { case failed(String) }

    static func main() throws {
        try testStripSoundAnnotations()
        try testStripFullwidthAnnotations()
        try testWhitespaceNormalization()
        try testFinalizeRejectsEmptyText()
        try testFinalizeAppliesDictionaryLast()
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
}
