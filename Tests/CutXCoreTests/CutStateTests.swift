import Foundation
import Testing
@testable import CutXCore

private let sample = [
    URL(fileURLWithPath: "/Users/x/Report.pdf"),
    URL(fileURLWithPath: "/Users/x/Screenshots"),
]

@Test func startsDisarmed() {
    let state = CutState()
    #expect(state.isArmed == false)
    #expect(state.items.isEmpty)
}

@Test func armingStoresItemsAndChangeCount() {
    var state = CutState()
    state.arm(items: sample, changeCount: 42)
    #expect(state.isArmed == true)
    #expect(state.items == sample)
    #expect(state.armedChangeCount == 42)
}

@Test func intactWhenChangeCountMatches() {
    var state = CutState()
    state.arm(items: sample, changeCount: 42)
    #expect(state.isIntact(currentChangeCount: 42) == true)
}

// The guard against acting on a pasteboard someone else overwrote.
@Test func notIntactWhenChangeCountMoved() {
    var state = CutState()
    state.arm(items: sample, changeCount: 42)
    #expect(state.isIntact(currentChangeCount: 43) == false)
}

@Test func disarmedStateIsNeverIntact() {
    let state = CutState()
    #expect(state.isIntact(currentChangeCount: 0) == false)
}

@Test func clearResetsEverything() {
    var state = CutState()
    state.arm(items: sample, changeCount: 42)
    state.clear()
    #expect(state.isArmed == false)
    #expect(state.items.isEmpty)
    #expect(state.isIntact(currentChangeCount: 42) == false)
}

@Test func armingWithNoItemsLeavesStateDisarmed() {
    var state = CutState()
    state.arm(items: [], changeCount: 42)
    #expect(state.isArmed == false)
}

@Test func displayNamesAreLastPathComponents() {
    var state = CutState()
    state.arm(items: sample, changeCount: 1)
    #expect(state.displayNames == ["Report.pdf", "Screenshots"])
}
