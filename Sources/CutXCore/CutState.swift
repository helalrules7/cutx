import Foundation

/// The single source of truth for what is marked for moving.
///
/// `armedChangeCount` records the pasteboard's `changeCount` at the moment of the
/// cut. If anything else writes to the pasteboard afterwards the count moves, the
/// state is no longer intact, and the paste must not proceed — otherwise Finder's
/// Move Item Here would act on content CutX never marked.
public struct CutState: Equatable, Sendable {
    public private(set) var items: [URL] = []
    public private(set) var armedChangeCount: Int = -1

    public init() {}

    public var isArmed: Bool { !items.isEmpty }

    public var displayNames: [String] { items.map(\.lastPathComponent) }

    public mutating func arm(items: [URL], changeCount: Int) {
        guard !items.isEmpty else { return }
        self.items = items
        self.armedChangeCount = changeCount
    }

    public mutating func clear() {
        items = []
        armedChangeCount = -1
    }

    public func isIntact(currentChangeCount: Int) -> Bool {
        isArmed && currentChangeCount == armedChangeCount
    }
}
