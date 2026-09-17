import Foundation
import Testing
@testable import CutXCore

private func url(_ name: String) -> URL { URL(fileURLWithPath: "/Users/x/\(name)") }

@Test func startsEmpty() {
    #expect(CutHistory().entries.isEmpty)
}

@Test func recordingPutsTheNewestFirst() {
    var h = CutHistory()
    h.record([url("a.txt")])
    h.record([url("b.txt")])
    #expect(h.entries.map(\.displayName) == ["b.txt", "a.txt"])
}

@Test func singleItemNamesItself() {
    var h = CutHistory()
    h.record([url("Report.pdf")])
    #expect(h.entries[0].displayName == "Report.pdf")
    #expect(h.entries[0].subtitle == "/Users/x")
}

// A group is labelled by its first item plus a count. The count's wording is the
// UI's job — this type must not hard-code an English word, or eleven languages
// would show it untranslated.
@Test func groupReportsFirstNameAndExtraCount() {
    var h = CutHistory()
    h.record([url("a.txt"), url("b.txt"), url("c.txt")])
    #expect(h.entries[0].displayName == "a.txt")
    #expect(h.entries[0].extraCount == 2)
}

@Test func singleItemHasNoExtras() {
    var h = CutHistory()
    h.record([url("solo.txt")])
    #expect(h.entries[0].extraCount == 0)
}

@Test func recordingNothingIsIgnored() {
    var h = CutHistory()
    h.record([])
    #expect(h.entries.isEmpty)
}

// Cutting the same files again should move that entry to the top rather than
// filling the list with duplicates of one file.
@Test func recordingTheSameFilesAgainMovesItToTheTop() {
    var h = CutHistory()
    h.record([url("a.txt")])
    h.record([url("b.txt")])
    h.record([url("a.txt")])
    #expect(h.entries.map(\.displayName) == ["a.txt", "b.txt"])
    #expect(h.entries.count == 2)
}

@Test func oldestFallsOffAtTheLimit() {
    var h = CutHistory()
    for i in 0..<(CutHistory.limit + 5) { h.record([url("f\(i).txt")]) }
    #expect(h.entries.count == CutHistory.limit)
    #expect(h.entries.first?.displayName == "f\(CutHistory.limit + 4).txt")
    #expect(h.entries.contains { $0.displayName == "f0.txt" } == false)
}

// After a paste the entry stays, pointing at where the file now lives, so the
// same file can be moved on again from history.
@Test func updatingPathsKeepsPositionAndRenames() {
    var h = CutHistory()
    h.record([url("a.txt")])
    h.record([url("b.txt")])
    let id = h.entries[1].id
    h.updatePaths(id: id, to: [URL(fileURLWithPath: "/Users/x/Archive/a.txt")])
    #expect(h.entries[1].urls.first?.path == "/Users/x/Archive/a.txt")
    #expect(h.entries[1].subtitle == "/Users/x/Archive")
    #expect(h.entries.map(\.displayName) == ["b.txt", "a.txt"])
}

@Test func updatingAnUnknownIdChangesNothing() {
    var h = CutHistory()
    h.record([url("a.txt")])
    let before = h
    h.updatePaths(id: UUID(), to: [url("z.txt")])
    #expect(h == before)
}

@Test func removeDropsOnlyThatEntry() {
    var h = CutHistory()
    h.record([url("a.txt")])
    h.record([url("b.txt")])
    h.remove(id: h.entries[0].id)
    #expect(h.entries.map(\.displayName) == ["a.txt"])
}

@Test func clearEmptiesEverything() {
    var h = CutHistory()
    h.record([url("a.txt")])
    h.clear()
    #expect(h.entries.isEmpty)
}

@Test func entryAtIndexIsBoundsSafe() {
    var h = CutHistory()
    h.record([url("a.txt")])
    #expect(h.entry(at: 0)?.displayName == "a.txt")
    #expect(h.entry(at: 1) == nil)
    #expect(h.entry(at: -1) == nil)
}

@Test func survivesACodableRoundTrip() throws {
    var h = CutHistory()
    h.record([url("a.txt"), url("b.txt")])
    let data = try JSONEncoder().encode(h)
    #expect(try JSONDecoder().decode(CutHistory.self, from: data) == h)
}
