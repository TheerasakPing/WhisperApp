import Foundation

@main
struct VoiceSnippetCoreTests {
    enum TestError: Error { case failed(String) }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        try testThaiInvocation()
        try testEnglishInvocationCaseInsensitive()
        try testMultipleInvocations()
        try testDisabledSnippetIsIgnored()
        try testUnknownInvocationIsPreserved()
        try testDoesNotMatchPartialTrigger()
        try testTemplateVariables()
        try testCorrectionPrompt()
        print("VoiceSnippetCoreTests: PASS")
    }

    static let context = VoiceSnippetExpansionContext(
        date: "2026-09-19",
        time: "07:30",
        clipboard: "PM2230"
    )

    static func testThaiInvocation() throws {
        let doc = VoiceSnippetDocument(snippets: [
            VoiceSnippet(trigger: "ลายเซ็น", expansion: "ขอบคุณครับ\nธีรศักดิ์")
        ])
        let result = VoiceSnippetEngine.expand(
            "ฝากตรวจสอบด้วย แทรก ลายเซ็น",
            document: doc,
            context: context
        )
        try expect(result == "ฝากตรวจสอบด้วย ขอบคุณครับ\nธีรศักดิ์",
                   "Thai explicit snippet invocation must expand")
    }

    static func testEnglishInvocationCaseInsensitive() throws {
        let doc = VoiceSnippetDocument(snippets: [
            VoiceSnippet(trigger: "signature", expansion: "Best regards,\nTheerasak")
        ])
        let result = VoiceSnippetEngine.expand(
            "Please review INSERT SIGNATURE",
            document: doc,
            context: context
        )
        try expect(result == "Please review Best regards,\nTheerasak",
                   "English invocation and ASCII trigger must match case-insensitively")
    }

    static func testMultipleInvocations() throws {
        let doc = VoiceSnippetDocument(snippets: [
            VoiceSnippet(trigger: "วันที่", expansion: "{date}"),
            VoiceSnippet(trigger: "คลิปบอร์ด", expansion: "{clipboard}")
        ])
        let result = VoiceSnippetEngine.expand(
            "วันที่ แทรก วันที่ ค่า แทรก คลิปบอร์ด",
            document: doc,
            context: context
        )
        try expect(result == "วันที่ 2026-09-19 ค่า PM2230",
                   "multiple snippet invocations must expand independently")
    }

    static func testDisabledSnippetIsIgnored() throws {
        let doc = VoiceSnippetDocument(snippets: [
            VoiceSnippet(trigger: "secret", expansion: "hidden", isEnabled: false)
        ])
        try expect(
            VoiceSnippetEngine.expand("insert secret", document: doc, context: context) == "insert secret",
            "disabled snippet must never expand"
        )
    }

    static func testUnknownInvocationIsPreserved() throws {
        let doc = VoiceSnippetDocument(snippets: [])
        let input = "แทรก ยังไม่มี"
        try expect(VoiceSnippetEngine.expand(input, document: doc, context: context) == input,
                   "unknown invocation must be preserved exactly")
    }

    static func testDoesNotMatchPartialTrigger() throws {
        let doc = VoiceSnippetDocument(snippets: [
            VoiceSnippet(trigger: "sign", expansion: "X")
        ])
        try expect(
            VoiceSnippetEngine.expand("insert signature", document: doc, context: context) == "insert signature",
            "snippet trigger must not match a prefix of another word"
        )
    }

    static func testTemplateVariables() throws {
        let doc = VoiceSnippetDocument(snippets: [
            VoiceSnippet(
                trigger: "status",
                expansion: "Date {date} Time {time} Clipboard={clipboard}"
            )
        ])
        let result = VoiceSnippetEngine.expand(
            "insert status",
            document: doc,
            context: context
        )
        try expect(result == "Date 2026-09-19 Time 07:30 Clipboard=PM2230",
                   "date/time/clipboard variables must resolve from runtime context")
    }

    static func testCorrectionPrompt() throws {
        let prompt = VoiceSnippetEngine.correctionPromptInstructions
        try expect(prompt.contains("แทรก") && prompt.contains("insert"),
                   "AI prompt must identify explicit snippet commands")
        try expect(prompt.contains("exactly unchanged"),
                   "AI must preserve snippet invocation until post-correction expansion")
    }
}
