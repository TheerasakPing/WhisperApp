import SwiftUI

/// Dictionary V2 editor. Rich metadata is persisted through DictionaryV2Store;
/// the store keeps the legacy correction projection in sync for the existing runtime.
struct DictionaryView: View {
    @State private var document = DictionaryDocument()
    @State private var spoken = ""
    @State private var preferred = ""
    @State private var aliases = ""
    @State private var category = "General"
    @State private var message = ""

    private let store = DictionaryV2Store.shared

    private var readySuggestions: [DictionarySuggestion] {
        document.suggestions.filter { $0.isReady }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                addEntryCard

                if !readySuggestions.isEmpty {
                    suggestionsCard
                }

                entriesCard

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message.hasPrefix("⚠️") ? .orange : .secondary)
                }

                Text("Dictionary metadata and learning decisions stay local on this Mac. A compatibility correction list is maintained automatically so existing dictation behavior keeps working.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(width: 620, height: 620)
        .onAppear(perform: loadDocument)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Personal Dictionary")
                .font(.title2.bold())
            Text("Teach Whisper product names, people, technical terms, abbreviations, and the different ways you may pronounce them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var addEntryCard: some View {
        GroupBox("Add term") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Spoken / mis-heard form", text: $spoken)
                        .textFieldStyle(.roundedBorder)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    TextField("Preferred text", text: $preferred)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 8) {
                    TextField("Aliases, separated by commas", text: $aliases)
                        .textFieldStyle(.roundedBorder)
                    TextField("Category", text: $category)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    Button(action: addEntry) {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Text("Example: พีเอ็มสองสองสามศูนย์ → PM2230 · aliases: pm สองสองสามศูนย์, พีเอ็ม 2230")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var suggestionsCard: some View {
        GroupBox("Learning suggestions") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Whisper only saves a learned term after you approve it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(readySuggestions) { suggestion in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(suggestion.spoken)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(suggestion.preferred).bold()
                            }
                            Text("Seen \(suggestion.occurrences) times")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reject", role: .destructive) {
                            rejectSuggestion(suggestion)
                        }
                        Button("Accept") {
                            acceptSuggestion(suggestion)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.08)))
                }
            }
            .padding(.top, 4)
        }
    }

    private var entriesCard: some View {
        GroupBox("Terms (\(document.entries.count))") {
            VStack(alignment: .leading, spacing: 8) {
                if document.entries.isEmpty {
                    Text("No terms yet. Existing correction rules are imported automatically the first time Dictionary V2 opens.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(document.entries) { entry in
                        entryRow(entry)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func entryRow(_ entry: DictionaryEntry) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Button {
                toggleEntry(entry.id)
            } label: {
                Image(systemName: entry.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(entry.isEnabled ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(entry.isEnabled ? "Disable this term" : "Enable this term")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.spoken)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.preferred)
                        .bold()
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(entry.category.isEmpty ? "General" : entry.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    if !entry.aliases.isEmpty {
                        Text("Aliases: " + entry.aliases.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .opacity(entry.isEnabled ? 1 : 0.55)

            Spacer(minLength: 6)

            Button(role: .destructive) {
                removeEntry(entry.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.07)))
    }

    private func loadDocument() {
        do {
            document = try store.load()
            message = document.entries.isEmpty ? "" : "✅ Dictionary ready"
        } catch {
            flash("⚠️ Could not load dictionary: \(error.localizedDescription)")
        }
    }

    private func saveDocument(successMessage: String? = nil) {
        do {
            try store.save(document)
            if let successMessage { flash(successMessage) }
        } catch {
            flash("⚠️ Could not save dictionary: \(error.localizedDescription)")
        }
    }

    private func addEntry() {
        let cleanSpoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPreferred = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSpoken.isEmpty, !cleanPreferred.isEmpty else {
            flash("⚠️ Fill in spoken and preferred text")
            return
        }

        let aliasList = aliases
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != cleanSpoken }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) { result.append(value) }
            }

        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        document.entries.append(DictionaryEntry(
            spoken: cleanSpoken,
            preferred: cleanPreferred,
            aliases: aliasList,
            category: cleanCategory.isEmpty ? "General" : cleanCategory,
            scope: .global,
            isEnabled: true
        ))

        spoken = ""
        preferred = ""
        aliases = ""
        saveDocument(successMessage: "✅ Added")
    }

    private func toggleEntry(_ id: UUID) {
        guard let index = document.entries.firstIndex(where: { $0.id == id }) else { return }
        document.entries[index].isEnabled.toggle()
        saveDocument()
    }

    private func removeEntry(_ id: UUID) {
        document.entries.removeAll { $0.id == id }
        saveDocument(successMessage: "✅ Removed")
    }

    private func acceptSuggestion(_ suggestion: DictionarySuggestion) {
        do {
            try DictionaryLearningEngine.acceptSuggestion(
                suggestion.id,
                category: "Learned",
                scope: .global,
                in: &document
            )
            saveDocument(successMessage: "✅ Learned \(suggestion.preferred)")
        } catch {
            flash("⚠️ Suggestion is no longer available")
        }
    }

    private func rejectSuggestion(_ suggestion: DictionarySuggestion) {
        DictionaryLearningEngine.rejectSuggestion(suggestion.id, in: &document)
        saveDocument(successMessage: "✅ Suggestion dismissed")
    }

    private func flash(_ text: String) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if message == text { message = "" }
        }
    }
}
