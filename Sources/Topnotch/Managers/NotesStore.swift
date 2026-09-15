import Foundation
import Combine

/// A single free-form scratch pad, persisted to disk as plain text.
final class NotesStore: ObservableObject {
    @Published var text: String {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Topnotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("notes.txt")
        text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let url = fileURL
        let snapshot = text
        let item = DispatchWorkItem { try? snapshot.write(to: url, atomically: true, encoding: .utf8) }
        saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: item)
    }
}
