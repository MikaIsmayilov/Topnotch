import Foundation
import AppKit
import Combine

struct TrayItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var name: String { url.lastPathComponent }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// A temporary shelf for files dragged onto the notch. Files are copied into a scratch
/// directory so the tray keeps working even if the user's Finder window closes or the
/// original file moves; dragging an item back out drags the copy.
final class FileTrayStore: ObservableObject {
    @Published private(set) var items: [TrayItem] = []

    private let trayDirectory: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        trayDirectory = caches.appendingPathComponent("Topnotch/Tray", isDirectory: true)
        try? FileManager.default.createDirectory(at: trayDirectory, withIntermediateDirectories: true)
        reload()
    }

    private func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: trayDirectory, includingPropertiesForKeys: nil)) ?? []
        items = urls.map { TrayItem(url: $0) }
    }

    func add(urls: [URL]) {
        for url in urls {
            let destination = trayDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
                items.append(TrayItem(url: destination))
            } catch {
                // If it can't be copied (e.g. permissions), still reference the original.
                items.append(TrayItem(url: url))
            }
        }
    }

    func remove(_ item: TrayItem) {
        try? FileManager.default.removeItem(at: item.url)
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        for item in items {
            try? FileManager.default.removeItem(at: item.url)
        }
        items.removeAll()
    }

    func reveal(_ item: TrayItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func open(_ item: TrayItem) {
        NSWorkspace.shared.open(item.url)
    }
}
