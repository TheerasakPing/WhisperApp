import SwiftUI

#if os(macOS)
struct ProfilesView: View {
    @State private var document = AppProfileDocument()
    @State private var runningApps: [RunningApplicationChoice] = []
    @State private var newName = ""
    @State private var selectedBundleIdentifier = ""
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("App-aware Profiles", systemImage: "app.badge.checkmark")
                .font(.subheadline).bold()

            Text("Override provider, model, language, prompt and app-scoped dictionary rules for specific foreground apps. Blank values inherit global Settings.")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack {
                TextField("Profile name", text: $newName)
                    .textFieldStyle(.roundedBorder)

                Picker("Target app", selection: $selectedBundleIdentifier) {
                    Text("Choose running app…").tag("")
                    ForEach(runningApps) { app in
                        Text("\(app.name) — \(app.bundleIdentifier)")
                            .tag(app.bundleIdentifier)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)

                Button("Add") { addProfile() }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedBundleIdentifier.isEmpty)
            }

            if document.profiles.isEmpty {
                Text("No profiles yet. Start the target app, then choose it above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach($document.profiles) { $profile in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Bundle identifiers (comma separated)", text: bundleIdentifiersBinding($profile))
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Picker("STT", selection: optionalStringBinding($profile.sttProviderID)) {
                                    Text("STT: Inherit").tag("")
                                    ForEach(STTRegistry.all) { provider in
                                        Text(provider.name).tag(provider.id)
                                    }
                                }
                                TextField("STT model (inherit)", text: optionalStringBinding($profile.sttModel))
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Picker("AI", selection: optionalStringBinding($profile.llmProviderID)) {
                                    Text("AI: Inherit").tag("")
                                    ForEach(LLMRegistry.all) { provider in
                                        Text(provider.name).tag(provider.id)
                                    }
                                }
                                TextField("AI model (inherit)", text: optionalStringBinding($profile.llmModel))
                                    .textFieldStyle(.roundedBorder)
                            }

                            Picker("Language", selection: optionalStringBinding($profile.language)) {
                                Text("Language: Inherit").tag("")
                                Text("Auto").tag("auto")
                                Text("Thai + English (Mixed)").tag("th-en")
                                Text("Thai").tag("th")
                                Text("English").tag("en")
                            }
                            .frame(maxWidth: 220)

                            TextField("Custom correction prompt (optional)", text: optionalStringBinding($profile.customPrompt), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...5)

                            HStack {
                                Spacer()
                                Button("Delete", role: .destructive) {
                                    deleteProfile(profile.id)
                                }
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        HStack {
                            Toggle("", isOn: $profile.isEnabled)
                                .labelsHidden()
                            TextField("Profile name", text: $profile.name)
                                .textFieldStyle(.plain)
                                .font(.body.bold())
                            Spacer()
                            if let bundle = profile.bundleIdentifiers.first {
                                Text(bundle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack {
                Button("Refresh Apps") { refreshApps() }
                Button("Save Profiles") { save() }
                    .buttonStyle(.borderedProminent)
                if !message.isEmpty {
                    Text(message).font(.caption)
                }
                Spacer()
            }
        }
        .onAppear {
            reload()
            refreshApps()
        }
    }

    private func optionalStringBinding(_ binding: Binding<String?>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                binding.wrappedValue = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func bundleIdentifiersBinding(_ profile: Binding<AppProfile>) -> Binding<String> {
        Binding(
            get: { profile.wrappedValue.bundleIdentifiers.joined(separator: ", ") },
            set: { value in
                profile.wrappedValue.bundleIdentifiers = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private func addProfile() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !selectedBundleIdentifier.isEmpty else { return }
        document.profiles.append(AppProfile(
            name: name,
            bundleIdentifiers: [selectedBundleIdentifier]
        ))
        newName = ""
        selectedBundleIdentifier = ""
        save()
    }

    private func deleteProfile(_ id: UUID) {
        document.profiles.removeAll { $0.id == id }
        save()
    }

    private func reload() {
        do {
            document = try AppProfileStore.shared.load()
            message = ""
        } catch {
            document = AppProfileDocument()
            message = "Could not load profiles"
        }
    }

    private func save() {
        do {
            try AppProfileStore.shared.save(document)
            message = "✅ Saved"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if message == "✅ Saved" { message = "" }
            }
        } catch {
            message = "❌ Could not save"
        }
    }

    private func refreshApps() {
        runningApps = AppContextService.shared.runningApplications()
    }
}
#endif
