import SwiftUI

struct HistoryView: View {
    @State private var document = HistoryDocument()
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictation History").font(.title2).bold()
                    Text("Stored only on this Mac in ~/.whisperapp/history-v1.json")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Picker("Keep", selection: retentionBinding) {
                    ForEach(HistoryRetention.allCases) { retention in
                        Text(retention.displayName).tag(retention)
                    }
                }
                .frame(width: 170)
            }

            if document.records.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(document.retention == .off ? "History is turned off" : "No dictation history yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(document.records) { record in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundColor(.secondary)
                                Text(record.language.uppercased())
                                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.quaternary).clipShape(Capsule())
                                Text(record.source == .cloud ? "Cloud" : "Local")
                                    .font(.caption2).foregroundColor(.secondary)
                                Spacer()
                            }

                            Text(record.finalText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Button("Copy") {
                                    Paster.copy(record.finalText)
                                    message = "Copied"
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    delete(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .listStyle(.inset)
            }

            HStack {
                Button("Refresh") { reload() }
                if !document.records.isEmpty {
                    Button("Clear All", role: .destructive) {
                        clearAll()
                    }
                }
                Spacer()
                if !message.isEmpty {
                    Text(message).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
        .frame(minWidth: 600, minHeight: 460)
        .onAppear { reload() }
    }

    private var retentionBinding: Binding<HistoryRetention> {
        Binding(
            get: { document.retention },
            set: { newValue in
                do {
                    document = try HistoryStore.shared.setRetention(newValue)
                    message = newValue == .off ? "History disabled" : "Retention updated"
                } catch {
                    message = "Could not update retention"
                }
            }
        )
    }

    private func reload() {
        do {
            document = try HistoryStore.shared.load()
            message = ""
        } catch {
            document = HistoryDocument()
            message = "Could not load history"
        }
    }

    private func delete(_ record: HistoryRecord) {
        do {
            try HistoryStore.shared.delete(id: record.id)
            reload()
        } catch {
            message = "Could not delete item"
        }
    }

    private func clearAll() {
        do {
            try HistoryStore.shared.clear()
            reload()
        } catch {
            message = "Could not clear history"
        }
    }
}
