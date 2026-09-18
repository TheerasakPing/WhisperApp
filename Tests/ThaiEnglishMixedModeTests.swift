import Foundation

@main
struct ThaiEnglishMixedModeTests {
    enum TestError: Error { case failed(String) }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func main() throws {
        try testLanguageRegistration()
        try testCloudAndLocalLanguagePolicy()
        try testProtectsLatinTermsAndIdentifiers()
        try testRestoresProtectedTermsExactly()
        try testMixedCorrectionInstructions()
        print("ThaiEnglishMixedModeTests: PASS")
    }

    static func testLanguageRegistration() throws {
        let language = Languages.find("th-en")
        try expect(language?.name == "Thai + English (Mixed)",
                   "th-en must resolve to the mixed Thai-English language")
    }

    static func testCloudAndLocalLanguagePolicy() throws {
        try expect(ThaiEnglishMixedMode.isEnabled(language: "th-en"),
                   "th-en must enable mixed mode")
        try expect(ThaiEnglishMixedMode.cloudLanguageCode(language: "th-en") == nil,
                   "mixed cloud STT must use provider auto-detection")
        try expect(ThaiEnglishMixedMode.localWhisperLanguage(language: "th-en") == "auto",
                   "mixed local Whisper must use auto language detection")
        try expect(ThaiEnglishMixedMode.localWhisperLanguage(language: "th") == "th",
                   "normal language selection must remain unchanged")
    }

    static func testProtectsLatinTermsAndIdentifiers() throws {
        let input = "ช่วย update firmware ของ ESP32-S3 แล้ว push ขึ้น GitHub ผ่าน MQTT"
        let protected = ThaiEnglishMixedMode.protectLatinTerms(in: input)

        try expect(protected.terms == ["ESP32-S3", "GitHub", "MQTT"],
                   "mixed mode must shield technical/proper identifiers without hiding normal English words")
        for term in protected.terms {
            try expect(!protected.text.contains(term),
                       "protected text must hide original technical term: \(term)")
        }
        try expect(protected.text.contains("update") &&
                   protected.text.contains("firmware") &&
                   protected.text.contains("push"),
                   "normal English words must remain visible so the correction model can fix them")
        try expect(protected.text.contains("ช่วย") && protected.text.contains("แล้ว"),
                   "Thai text must remain available to the correction model")
    }

    static func testRestoresProtectedTermsExactly() throws {
        let input = "ช่วย update ESP32-S3 แล้ว push ขึ้น GitHub"
        let protected = ThaiEnglishMixedMode.protectLatinTerms(in: input)
        let corrected = protected.text.replacingOccurrences(of: "ช่วย", with: "ช่วย")
        let restored = protected.restore(in: corrected)

        try expect(restored == input,
                   "protected Latin terms must restore with original spelling and casing")
    }

    static func testMixedCorrectionInstructions() throws {
        let instructions = ThaiEnglishMixedMode.correctionInstructions(protectedTermCount: 3)
        try expect(instructions.contains("Do not translate"),
                   "mixed prompt must forbid translation")
        try expect(instructions.contains("Latin script"),
                   "mixed prompt must preserve English words in Latin script")
        try expect(instructions.contains("⟪0⟫"),
                   "mixed prompt must explain protected placeholders")
    }
}
