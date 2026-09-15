import SwiftUI

struct ClipboardWidget: View {
    @ObservedObject var store: ClipboardStore
    @State private var justCopied: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(
                    title: "Clipboard",
                    detail: store.items.isEmpty ? nil : "\(store.items.count) of \(ClipboardStore.limit)"
                )
                Spacer()
                if !store.items.isEmpty {
                    Button("Clear") { store.clear() }
                        .buttonStyle(.plain)
                        .font(.ui(11, .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if store.items.isEmpty {
                EmptyStateView(
                    symbol: "doc.on.clipboard",
                    title: "Nothing copied yet",
                    subtitle: "Copied text shows up here — passwords are skipped"
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(store.items) { item in
                            row(item)
                        }
                    }
                }
            }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        let copied = justCopied == item.id
        return Button {
            store.copy(item)
            justCopied = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if justCopied == item.id { justCopied = nil }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.ui(10.5))
                    .foregroundStyle(copied ? Theme.defaultAccent : Theme.textTertiary)
                    .frame(width: 14)

                Text(item.preview)
                    .font(.ui(11.5))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(copied ? "Copied" : Self.relative(item.date))
                    .font(.ui(9.5))
                    .foregroundStyle(copied ? Theme.defaultAccent : Theme.textTertiary)
                    .fixedSize()
            }
            .padding(.horizontal, 9)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.surface)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(item.text.count > 400 ? String(item.text.prefix(400)) + "…" : item.text)
        .contextMenu {
            Button("Copy") { store.copy(item) }
            Divider()
            Button("Remove", role: .destructive) { store.remove(item) }
        }
    }

    private static func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86_400)d"
    }
}
