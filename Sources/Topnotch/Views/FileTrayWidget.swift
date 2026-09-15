import SwiftUI

struct FileTrayWidget: View {
    @ObservedObject var store: FileTrayStore

    private let columns = [GridItem(.adaptive(minimum: 74, maximum: 74), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(
                    title: "Files",
                    detail: store.items.isEmpty ? nil : "\(store.items.count) item\(store.items.count == 1 ? "" : "s")"
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
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(Theme.hairline)
                    EmptyStateView(
                        symbol: "arrow.down.doc",
                        title: "Drop files here",
                        subtitle: "Drag anything from Finder onto the notch to shelve it"
                    )
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(store.items) { item in
                            FileTile(item: item, store: store)
                        }
                    }
                }
            }
        }
    }
}

private struct FileTile: View {
    let item: TrayItem
    let store: FileTrayStore

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 34, height: 34)
            Text(item.name)
                .font(.ui(9.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(width: 74, height: 76)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? Theme.surfaceRaised : Theme.surface)
        )
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { store.open(item) }
        .contextMenu {
            Button("Open") { store.open(item) }
            Button("Reveal in Finder") { store.reveal(item) }
            Divider()
            Button("Remove", role: .destructive) { store.remove(item) }
        }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .help(item.name)
    }
}
