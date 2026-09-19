import SwiftUI

struct CommandModeView: View {
    @ObservedObject var controller: CommandModeController
    var onClose: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Command Mode", systemImage: "sparkles")
                    .font(.title2.bold())
                Spacer()
                Button("Close", action: onClose)
            }

            Text("Selected text")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView {
                Text(controller.selectedText.isEmpty ? "No selected text" : controller.selectedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(minHeight: 100, maxHeight: 180)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
            )

            LazyVGrid(columns: columns, spacing: 10) {
                actionButton(.polite, title: "Polite", icon: "hand.thumbsup")
                actionButton(.concise, title: "Concise", icon: "scissors")
                actionButton(.formal, title: "Formal", icon: "briefcase")
                actionButton(.summarize, title: "Summarize", icon: "text.alignleft")
                actionButton(.translateThai, title: "Translate Thai", icon: "character.book.closed")
                actionButton(.translateEnglish, title: "Translate English", icon: "globe")
            }

            if !controller.resultText.isEmpty {
                Text("Result")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(controller.resultText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                }
                .frame(maxHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.06))
                )
            }

            HStack {
                Text(controller.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("AI actions only transform text; they never execute commands.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 560, height: 500)
    }

    private func actionButton(_ action: AIAction, title: String, icon: String) -> some View {
        Button {
            controller.apply(action)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isBusy)
    }

    private var isBusy: Bool {
        if case .transforming = controller.state { return true }
        return controller.selectedText.isEmpty
    }
}
