import Foundation

@main
struct VoiceCommandCoreTests {
    enum TestError: Error { case failed(String) }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        try testThaiFormattingCommands()
        try testEnglishFormattingCommands()
        try testDeletePreviousSentence()
        try testThaiBacktracking()
        try testEnglishBacktracking()
        try testTechnicalBacktracking()
        try testAmbiguousBacktrackingPreservesContext()
        try testPromptInstructions()
        print("VoiceCommandCoreTests: PASS")
    }

    static func testThaiFormattingCommands() throws {
        let input = "สวัสดี ขึ้นบรรทัดใหม่ วันนี้อากาศดี ย่อหน้าใหม่ รายการ หัวข้อย่อย แอปเปิล หัวข้อย่อย กล้วย"
        let expected = "สวัสดี\nวันนี้อากาศดี\n\nรายการ\n• แอปเปิล\n• กล้วย"
        try expect(VoiceCommandProcessor.apply(to: input) == expected,
                   "Thai newline/paragraph/bullet commands must become formatting")
    }

    static func testEnglishFormattingCommands() throws {
        let input = "Hello new line world new paragraph Tasks bullet point one bullet point two"
        let expected = "Hello\nworld\n\nTasks\n• one\n• two"
        try expect(VoiceCommandProcessor.apply(to: input) == expected,
                   "English formatting commands must be case-insensitive and deterministic")
    }

    static func testDeletePreviousSentence() throws {
        let input = "ส่งอีเมลให้ทีม. นัดประชุมวันศุกร์. ลบประโยคก่อนหน้า นัดประชุมวันพฤหัส"
        let expected = "ส่งอีเมลให้ทีม. นัดประชุมวันพฤหัส"
        try expect(VoiceCommandProcessor.apply(to: input) == expected,
                   "delete previous sentence must remove only the immediately preceding sentence")
    }

    static func testThaiBacktracking() throws {
        let input = "ประชุมวันศุกร์ ไม่ใช่ วันพฤหัส"
        try expect(VoiceCommandProcessor.apply(to: input) == "ประชุมวันพฤหัส",
                   "Thai self-correction must replace the rejected suffix when a safe shared anchor exists")
    }

    static func testEnglishBacktracking() throws {
        let input = "meeting on Friday I mean Thursday"
        try expect(VoiceCommandProcessor.apply(to: input) == "meeting on Thursday",
                   "English I mean correction must replace the previous word")
    }

    static func testTechnicalBacktracking() throws {
        let input = "ใช้ ESP32-S3 ไม่ใช่ ESP32-C3 แล้วทดสอบ MQTT"
        try expect(VoiceCommandProcessor.apply(to: input) == "ใช้ ESP32-C3 แล้วทดสอบ MQTT",
                   "technical self-correction must preserve prefix context and replace the model identifier")
    }

    static func testAmbiguousBacktrackingPreservesContext() throws {
        let input = "โทรหาสมชาย ไม่ใช่ สมศรี"
        try expect(VoiceCommandProcessor.apply(to: input) == input,
                   "ambiguous Thai correction must preserve the original cue instead of deleting context")
    }

    static func testPromptInstructions() throws {
        let prompt = VoiceCommandProcessor.correctionPromptInstructions
        try expect(prompt.contains("ไม่ใช่") && prompt.contains("I mean"),
                   "correction prompt must teach the LLM unresolved self-correction cues")
        try expect(prompt.contains("preserve the surrounding context"),
                   "LLM fallback must preserve context while resolving corrections")
    }
}
