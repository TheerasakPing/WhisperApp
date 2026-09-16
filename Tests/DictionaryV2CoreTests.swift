import Foundation

@main
struct DictionaryV2CoreTests {
    enum TestError: Error { case failed(String) }

    static func main() throws {
        try testLegacyMigrationPreservesRules()
        try testAliasesProjectToLegacyRules()
        try testDisabledEntriesDoNotProject()
        try testAppScopedEntriesOnlyApplyToMatchingApp()
        try testLearningSuggestionAppearsAfterRepeatedCorrection()
        try testLearningSuggestionAcceptAndReject()
        try testStoreRoundTripAndLegacyProjection()
        print("DictionaryV2CoreTests: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestError.failed(message) }
    }

    static func testLegacyMigrationPreservesRules() throws {
        let legacy = """
        # comment
        พีเอ็มสองสองสามศูนย์ -> PM2230
        esp สามสอง -> ESP32
        invalid line
        """
        let document = DictionaryV2Codec.migrateLegacy(legacy)
        try expect(document.schemaVersion == 2, "schema version must be 2")
        try expect(document.entries.count == 2, "legacy rules should migrate to two entries")
        try expect(document.entries[0].spoken == "พีเอ็มสองสองสามศูนย์", "first spoken form mismatch")
        try expect(document.entries[0].preferred == "PM2230", "first preferred form mismatch")
        try expect(document.entries.allSatisfy { $0.scope == .global }, "legacy entries must migrate as global")
    }

    static func testAliasesProjectToLegacyRules() throws {
        let entry = DictionaryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            spoken: "พีเอ็มสองสองสามศูนย์",
            preferred: "PM2230",
            aliases: ["pm สองสองสามศูนย์", "พีเอ็ม 2230", "พีเอ็ม 2230"],
            category: "Engineering",
            scope: .global,
            isEnabled: true
        )
        let document = DictionaryDocument(entries: [entry])
        let projected = DictionaryV2Codec.projectLegacy(document, bundleIdentifier: nil)
        try expect(projected.contains("พีเอ็มสองสองสามศูนย์ -> PM2230"), "primary spoken form missing")
        try expect(projected.contains("pm สองสองสามศูนย์ -> PM2230"), "alias rule missing")
        try expect(projected.components(separatedBy: "พีเอ็ม 2230 -> PM2230").count == 2,
                   "duplicate aliases should project only once")
    }

    static func testDisabledEntriesDoNotProject() throws {
        let entry = DictionaryEntry(
            spoken: "bad",
            preferred: "good",
            aliases: [],
            category: "General",
            scope: .global,
            isEnabled: false
        )
        let projected = DictionaryV2Codec.projectLegacy(DictionaryDocument(entries: [entry]), bundleIdentifier: nil)
        try expect(!projected.contains("bad -> good"), "disabled entry must not project")
    }

    static func testAppScopedEntriesOnlyApplyToMatchingApp() throws {
        let entry = DictionaryEntry(
            spoken: "prod",
            preferred: "Production",
            aliases: [],
            category: "Work",
            scope: .app(bundleIdentifier: "com.microsoft.VSCode"),
            isEnabled: true
        )
        let document = DictionaryDocument(entries: [entry])
        let vscode = DictionaryV2Codec.activeRules(document, bundleIdentifier: "com.microsoft.VSCode")
        let line = DictionaryV2Codec.activeRules(document, bundleIdentifier: "jp.naver.line.mac")
        try expect(vscode.count == 1, "matching app should receive scoped entry")
        try expect(line.isEmpty, "non-matching app must not receive scoped entry")
    }

    static func testLearningSuggestionAppearsAfterRepeatedCorrection() throws {
        var document = DictionaryDocument()
        DictionaryLearningEngine.recordCorrection(
            original: "ใช้ พีเอ็มสองสองสามศูนย์ วัดค่า",
            corrected: "ใช้ PM2230 วัดค่า",
            in: &document,
            threshold: 2
        )
        try expect(document.suggestions.count == 1, "first correction should create a tracked suggestion")
        try expect(document.suggestions[0].occurrences == 1, "first correction occurrence mismatch")
        try expect(!document.suggestions[0].isReady, "suggestion must not be ready after one observation")

        DictionaryLearningEngine.recordCorrection(
            original: "ใช้ พีเอ็มสองสองสามศูนย์ วัดค่า",
            corrected: "ใช้ PM2230 วัดค่า",
            in: &document,
            threshold: 2
        )
        try expect(document.suggestions[0].occurrences == 2, "second correction should increment occurrence count")
        try expect(document.suggestions[0].isReady, "suggestion should be ready at threshold")
        try expect(document.suggestions[0].spoken == "พีเอ็มสองสองสามศูนย์", "learned spoken span mismatch")
        try expect(document.suggestions[0].preferred == "PM2230", "learned preferred span mismatch")
    }

    static func testLearningSuggestionAcceptAndReject() throws {
        let suggestion1 = DictionarySuggestion(spoken: "อีเอสพีสามสอง", preferred: "ESP32", occurrences: 3, isReady: true)
        let suggestion2 = DictionarySuggestion(spoken: "มอดบัส", preferred: "Modbus", occurrences: 2, isReady: true)
        var document = DictionaryDocument(suggestions: [suggestion1, suggestion2])

        try DictionaryLearningEngine.acceptSuggestion(suggestion1.id, category: "Engineering", scope: .global, in: &document)
        try expect(document.entries.contains { $0.spoken == "อีเอสพีสามสอง" && $0.preferred == "ESP32" },
                   "accepted suggestion should become a dictionary entry")
        try expect(!document.suggestions.contains { $0.id == suggestion1.id }, "accepted suggestion should leave pending list")

        DictionaryLearningEngine.rejectSuggestion(suggestion2.id, in: &document)
        try expect(!document.suggestions.contains { $0.id == suggestion2.id }, "rejected suggestion should be removed")
        try expect(document.rejectedPairs.contains("มอดบัส\u{001F}Modbus"), "rejected pair should be remembered")
    }

    static func testStoreRoundTripAndLegacyProjection() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-dictionary-v2-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DictionaryV2Store(directoryURL: root)
        let entry = DictionaryEntry(
            spoken: "อีเอสพีสามสอง",
            preferred: "ESP32",
            aliases: ["ESP สามสอง"],
            category: "Engineering",
            scope: .global,
            isEnabled: true
        )
        let document = DictionaryDocument(entries: [entry])
        try store.save(document)
        let loaded = try store.load()
        try expect(loaded.entries.count == 1, "saved V2 entry should round-trip")
        try expect(loaded.entries[0].aliases == ["ESP สามสอง"], "aliases should round-trip")

        let legacy = try String(contentsOf: store.legacyURL, encoding: .utf8)
        try expect(legacy.contains("อีเอสพีสามสอง -> ESP32"), "store should write primary legacy projection")
        try expect(legacy.contains("ESP สามสอง -> ESP32"), "store should write alias legacy projection")
    }
}
