import SwiftUI

struct NotesWidget: View {
    @ObservedObject var store: NotesStore

    private var wordCount: Int {
        store.text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Notes", detail: wordCount == 0 ? nil : "\(wordCount) word\(wordCount == 1 ? "" : "s")")
                Spacer()
                if !store.text.isEmpty {
                    Button("Clear") { store.text = "" }
                        .buttonStyle(.plain)
                        .font(.ui(11, .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Placeholder shares the editor's padding context and only adds the text
            // container's own 5pt line-fragment padding, so it lands exactly on the
            // caret instead of being positioned with guessed insets.
            ZStack(alignment: .topLeading) {
                TextEditor(text: $store.text)
                    .scrollContentBackground(.hidden)
                    .font(.ui(12.5))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(2)

                if store.text.isEmpty {
                    Text("Jot something down…")
                        .font(.ui(12.5))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
        }
    }
}
