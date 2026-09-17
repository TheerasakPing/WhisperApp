import SwiftUI

struct ProviderFallbackSettingsView: View {
    @State private var sttFallbackIDs: [String] = ProviderFallbackSettingsView.slots(STTSettings.fallbackProviderIDs)
    @State private var llmFallbackIDs: [String] = ProviderFallbackSettingsView.slots(LLMSettings.fallbackProviderIDs)
    @State private var fallbackToLocalWhisper = STTSettings.fallbackToLocalWhisper
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Automatic Provider Fallback", systemImage: "arrow.triangle.branch")
                .font(.subheadline).bold()

            Text("Providers are tried from top to bottom only when the previous provider fails. Leave a slot as None to skip it. Configure each provider's API key/model/endpoint in the sections above first.")
                .font(.caption2).foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 18) {
                fallbackColumn(title: "Speech-to-Text", providers: STTRegistry.all.map { ($0.id, $0.name) }, ids: $sttFallbackIDs)

                VStack(alignment: .leading, spacing: 7) {
                    fallbackColumn(title: "AI Correction", providers: LLMRegistry.all.map { ($0.id, $0.name) }, ids: $llmFallbackIDs)
                    Toggle("Fallback to Local Whisper", isOn: $fallbackToLocalWhisper)
                        .font(.caption)
                }
            }

            HStack {
                Button("Save Fallbacks") { save() }
                    .buttonStyle(.borderedProminent)
                if !message.isEmpty { Text(message).font(.caption) }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func fallbackColumn(title: String,
                                providers: [(String, String)],
                                ids: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).bold()
            ForEach(0..<3, id: \.self) { index in
                Picker("Fallback \(index + 1)", selection: ids[index]) {
                    Text("None").tag("")
                    ForEach(providers, id: \.0) { provider in
                        Text(provider.1).tag(provider.0)
                    }
                }
                .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        STTSettings.fallbackProviderIDs = sttFallbackIDs.filter { !$0.isEmpty }
        LLMSettings.fallbackProviderIDs = llmFallbackIDs.filter { !$0.isEmpty }
        STTSettings.fallbackToLocalWhisper = fallbackToLocalWhisper
        message = "✅ Saved"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if message == "✅ Saved" { message = "" }
        }
    }

    private static func slots(_ values: [String]) -> [String] {
        var result = Array(values.prefix(3))
        while result.count < 3 { result.append("") }
        return result
    }
}
