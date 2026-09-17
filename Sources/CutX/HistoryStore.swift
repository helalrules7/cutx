import Foundation
import CutXCore

/// Loads and saves the cut history as JSON.
///
/// Application Support is writable inside the App Sandbox without any extra
/// entitlement, which matters: the store build must keep running with nothing
/// beyond `app-sandbox`.
///
/// Writes are coalesced. A burst of cuts would otherwise rewrite the file on
/// every keystroke for no benefit.
final class HistoryStore {
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CutX", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }

    var history: CutHistory {
        didSet { scheduleSave() }
    }

    private var saveWorkItem: DispatchWorkItem?

    init() {
        // A corrupt or unreadable file must never stop the app launching; an
        // empty history is a perfectly good fallback.
        if let data = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode(CutHistory.self, from: data) {
            history = decoded
        } else {
            history = CutHistory()
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func save() {
        saveWorkItem?.cancel()
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
