import Foundation

/// One cut: the files that were marked, and when.
public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var urls: [URL]
    public let cutAt: Date

    public init(urls: [URL], cutAt: Date = Date()) {
        self.id = UUID()
        self.urls = urls
        self.cutAt = cutAt
    }

    /// The first item's file name. A group is labelled by its first item plus a
    /// count, but the wording of that count is localised, so the UI assembles it
    /// from `displayName` and `extraCount` rather than this type hard-coding
    /// English.
    public var displayName: String {
        urls.first?.lastPathComponent ?? ""
    }

    /// How many items came with the first one. Zero for a single-item cut.
    public var extraCount: Int {
        max(urls.count - 1, 0)
    }

    /// Where the files are now. Updated after a paste.
    public var subtitle: String {
        urls.first?.deletingLastPathComponent().path ?? ""
    }
}

/// The recent cuts, newest first, capped at `limit`.
///
/// Recording the same set of files again moves that entry to the top instead of
/// appending a duplicate: a list of twenty copies of one file helps nobody.
public struct CutHistory: Codable, Equatable, Sendable {
    public static let limit = 20

    public private(set) var entries: [HistoryEntry] = []

    public init() {}

    public mutating func record(_ urls: [URL], at date: Date = Date()) {
        guard !urls.isEmpty else { return }
        entries.removeAll { $0.urls == urls }
        entries.insert(HistoryEntry(urls: urls, cutAt: date), at: 0)
        if entries.count > Self.limit {
            entries.removeLast(entries.count - Self.limit)
        }
    }

    /// After Finder moves the files, the entry keeps its place in the list and
    /// points at the new location, so it can be moved on again from there.
    public mutating func updatePaths(id: UUID, to urls: [URL]) {
        guard !urls.isEmpty, let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].urls = urls
    }

    public mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public mutating func clear() {
        entries = []
    }

    public func entry(at index: Int) -> HistoryEntry? {
        entries.indices.contains(index) ? entries[index] : nil
    }
}
