import SwiftUI

struct SnippetsView: View {
    @State private var document = VoiceSnippetDocument()
    @State private var trigger = ""
    @State private var expansion = ""
    @State private var message = ""

    private let store = VoiceSnippetStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Voice Snippets")
                    .font(.title2.bold())
                Text("Say “แทรก <trigger>” or “insert <trigger>” to insert reusable text without sending the expansion through AI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GroupBox("Add snippet") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Trigger name, e.g. ลายเซ็น or signature", text: $trigger)
                        .textFieldStyle(.roundedBorder)

                    Text("Expansion")
                        .font(.caption.bold())
                    TextEditor(text: $expansion)
                        .font(.body)
                        .frame(minHeight: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25))
                        )

                    HStack {
                        Text("Variables: {date} · {time} · {clipboard}")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Add") { addSnippet() }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                expansion.isEmpty
                            )
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Snippets (\(document.snippets.count))") {
                if document.snippets.isEmpty {
                    Text("No snippets yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach($document.snippets) { $snippet in
                                snippetRow($snippet)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            HStack {
                Button("Save Changes") { save(success: "✅ Saved") }
                    .buttonStyle(.borderedProminent)
                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message.hasPrefix("⚠️") ? .orange : .secondary)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 640, height: 650)
        .onAppear(perform: load)
    }

    private func snippetRow(_ snippet: Binding<VoiceSnippet>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Toggle("", isOn: snippet.isEnabled)
                    .labelsHidden()
                TextField("Trigger", text: snippet.trigger)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive) {
                    remove(snippet.wrappedValue.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: snippet.expansion)
                .font(.body)
                .frame(minHeight: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.20))
                )
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
        .opacity(snippet.wrappedValue.isEnabled ? 1 : 0.55)
    }

    private func load() {
        do {
            document = try store.load()
            message = ""
        } catch {
            document = VoiceSnippetDocument()
            flash("⚠️ Could not load snippets: \(error.localizedDescription)")
        }
    }

    private func addSnippet() {
        let cleanTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTrigger.isEmpty, !expansion.isEmpty else { return }

        if document.snippets.contains(where: {
            $0.trigger.caseInsensitiveCompare(cleanTrigger) == .orderedSame
        }) {
            flash("⚠️ Trigger already exists")
            return
        }

        document.snippets.append(
            VoiceSnippet(trigger: cleanTrigger, expansion: expansion)
        )
        trigger = ""
        expansion = ""
        save(success: "✅ Added")
    }

    private func remove(_ id: UUID) {
        document.snippets.removeAll { $0.id == id }
        save(success: "✅ Removed")
    }

    private func save(success: String? = nil) {
        document.snippets = document.snippets.map {
            VoiceSnippet(
                id: $0.id,
                trigger: $0.trigger,
                expansion: $0.expansion,
                isEnabled: $0.isEnabled
            )
        }
        do {
            try store.save(document)
            if let success { flash(success) }
        } catch {
            flash("⚠️ Could not save snippets: \(error.localizedDescription)")
        }
    }

    private func flash(_ text: String) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if message == text { message = "" }
        }
    }
}
