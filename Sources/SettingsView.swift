import SwiftUI

struct SettingsView: View {
    // Hotkey
    @State private var hotkeyConfig = HotkeyManager.shared.currentConfig
    @State private var isRecordingHotkey = false

    // STT
    @State private var sttProviderID = STTSettings.providerID
    @State private var sttKey = ""
    @State private var sttModel = ""
    @State private var sttEndpoint = ""
    @State private var sttMsg = ""

    // LLM
    @State private var llmProviderID = LLMSettings.providerID
    @State private var llmKey = ""
    @State private var llmModel = ""
    @State private var llmEndpoint = ""
    @State private var llmMsg = ""
    @State private var llmModels: [String] = []
    @State private var llmLoadingModels = false

    private var sttProvider: STTProvider { STTRegistry.provider(id: sttProviderID) }
    private var llmProvider: LLMProvider { LLMRegistry.provider(id: llmProviderID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Whisper Settings").font(.title3).bold()

                hotkeySection
                Divider()
                sttSection
                Divider()
                llmSection

                Text("💡 Fix words the STT keeps mis-transcribing via Dictionary…")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(20)
        }
        .frame(width: 460, height: 720)
        .onAppear {
            loadSttFields()
            loadLlmFields()
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Global Hotkey", systemImage: "keyboard")
                .font(.subheadline).bold()
            HStack(spacing: 12) {
                Text("Shortcut:").font(.caption)
                HotkeyRecorderView(hotkey: $hotkeyConfig, isRecording: $isRecordingHotkey)
                    .frame(width: 180, height: 30)
                Button(isRecordingHotkey ? "Listening…" : "Change") { isRecordingHotkey.toggle() }
                    .disabled(isRecordingHotkey)
                Button("Reset") {
                    hotkeyConfig = .default
                    HotkeyManager.shared.updateConfig(hotkeyConfig)
                }
            }
            Toggle("Hold to talk (press & hold to record, release to stop)", isOn: $hotkeyConfig.isHoldMode)
                .font(.caption)
                .onChange(of: hotkeyConfig.isHoldMode) { _ in HotkeyManager.shared.updateConfig(hotkeyConfig) }
            Text("Toggle mode: double-tap to start, single tap to stop · Hold mode: press and hold to record")
                .font(.caption2).foregroundColor(.secondary)
        }
        .onChange(of: hotkeyConfig.keyCode) { _ in HotkeyManager.shared.updateConfig(hotkeyConfig) }
        .onChange(of: hotkeyConfig.modifiers) { _ in HotkeyManager.shared.updateConfig(hotkeyConfig) }
    }

    private var sttSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Speech-to-Text", systemImage: "waveform")
                .font(.subheadline).bold()
            Picker("Provider", selection: $sttProviderID) {
                ForEach(STTRegistry.all) { p in Text(p.name).tag(p.id) }
            }
            .onChange(of: sttProviderID) { _ in
                STTSettings.providerID = sttProviderID
                loadSttFields()
            }

            SecureField(sttProvider.envKey, text: $sttKey).textFieldStyle(.roundedBorder)
            TextField("Model: \(sttProvider.defaultModel)", text: $sttModel).textFieldStyle(.roundedBorder)
            TextField("Endpoint: \(sttProvider.defaultEndpoint)", text: $sttEndpoint).textFieldStyle(.roundedBorder)

            HStack {
                Button("Save STT") { saveStt() }.buttonStyle(.borderedProminent)
                if !sttMsg.isEmpty { Text(sttMsg).font(.caption) }
            }
            Text("Leave model/endpoint blank to use the provider default. Keys are stored locally.")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Text Correction", systemImage: "sparkles")
                .font(.subheadline).bold()
            Picker("Provider", selection: $llmProviderID) {
                ForEach(LLMRegistry.all) { p in Text(p.name).tag(p.id) }
            }
            .onChange(of: llmProviderID) { _ in
                LLMSettings.providerID = llmProviderID
                llmModels = []
                loadLlmFields()
            }

            if llmProvider.requiresAPIKey {
                SecureField(llmProvider.envKey, text: $llmKey).textFieldStyle(.roundedBorder)
            } else {
                Text("No API key required for this local provider.")
                    .font(.caption).foregroundColor(.secondary)
            }
            TextField(llmProvider.defaultModel.isEmpty ? "Model ID" : "Model: \(llmProvider.defaultModel)",
                      text: $llmModel)
                .textFieldStyle(.roundedBorder)
            TextField(llmProvider.defaultEndpoint.isEmpty ? "Endpoint URL (required)" : "Endpoint: \(llmProvider.defaultEndpoint)",
                      text: $llmEndpoint)
                .textFieldStyle(.roundedBorder)

            if llmProvider.modelsEndpoint != nil {
                HStack {
                    Button(llmLoadingModels ? "Loading Models…" : "Load Models") { loadModels() }
                        .disabled(llmLoadingModels)
                    if !llmModels.isEmpty {
                        Picker("Available", selection: $llmModel) {
                            Text("Use default (\(llmProvider.defaultModel))").tag("")
                            ForEach(llmModels, id: \.self) { model in Text(model).tag(model) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }
                }
            }

            HStack {
                Button("Save AI") { saveLlm() }.buttonStyle(.borderedProminent)
                if !llmMsg.isEmpty { Text(llmMsg).font(.caption) }
            }
            if llmProvider.id == "qwen_responses" {
                Text("Alibaba Model Studio Responses uses a workspace/region-specific endpoint. Paste the full /compatible-mode/v1/responses URL for your workspace.")
                    .font(.caption2).foregroundColor(.secondary)
            } else if llmProvider.id == "qwen" {
                Text("Alibaba Model Studio uses region/workspace-specific endpoints. Paste the full /chat/completions URL for your workspace.")
                    .font(.caption2).foregroundColor(.secondary)
            } else {
                Text("Leave model/endpoint blank to use the provider default. Custom and local providers require a model ID.")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private func loadSttFields() {
        let p = sttProvider
        sttKey = STTSettings.savedKeyFile(for: p)
        sttModel = STTSettings.savedModel(for: p)
        sttEndpoint = STTSettings.savedEndpoint(for: p)
    }

    private func saveStt() {
        let p = sttProvider
        STTSettings.providerID = p.id
        STTSettings.saveKey(sttKey, for: p)
        STTSettings.saveModel(sttModel, for: p)
        STTSettings.saveEndpoint(sttEndpoint, for: p)
        sttMsg = STTSettings.isConfigured(p) ? "✅ Saved" : "⚠️ Check key / model / endpoint"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { sttMsg = "" }
    }

    private func loadLlmFields() {
        let p = llmProvider
        llmKey = LLMSettings.savedKeyFile(for: p)
        llmModel = LLMSettings.savedModel(for: p)
        llmEndpoint = LLMSettings.savedEndpoint(for: p)
    }

    private func loadModels() {
        let p = llmProvider
        let typedKey = llmKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = typedKey.isEmpty ? LLMSettings.key(for: p) : typedKey
        llmLoadingModels = true
        llmMsg = "⏳ Loading models…"
        LLMModelCatalogService().fetch(provider: p, apiKey: key) { result in
            DispatchQueue.main.async {
                llmLoadingModels = false
                switch result {
                case .success(let models):
                    llmModels = models
                    llmMsg = "✅ \(models.count) models"
                case .failure(let error):
                    llmModels = []
                    llmMsg = "❌ \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveLlm() {
        let p = llmProvider
        LLMSettings.providerID = p.id
        if p.requiresAPIKey { LLMSettings.saveKey(llmKey, for: p) }
        LLMSettings.saveModel(llmModel, for: p)
        LLMSettings.saveEndpoint(llmEndpoint, for: p)
        llmMsg = LLMSettings.isConfigured(p) ? "✅ Saved" : "⚠️ Check key / model / endpoint"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { llmMsg = "" }
    }
}
