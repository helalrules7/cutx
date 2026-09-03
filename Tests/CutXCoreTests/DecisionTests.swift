import Testing
@testable import CutXCore

private func ctx(
    finder: Bool = true,
    selection: Bool = true,
    armed: Bool = true,
    intact: Bool = true,
    controlHotkeys: Bool = false
) -> Context {
    Context(
        finderFrontmost: finder,
        hasSelection: selection,
        isArmed: armed,
        pasteboardIntact: intact,
        controlHotkeysEnabled: controlHotkeys
    )
}

private func cmd(_ code: UInt16) -> KeyEvent {
    KeyEvent(keyCode: code, command: true, control: false, shift: false, option: false)
}

private func ctrl(_ code: UInt16) -> KeyEvent {
    KeyEvent(keyCode: code, command: false, control: true, shift: false, option: false)
}

// The single most important guarantee in the app: CutX is invisible outside Finder.
@Test func cutOutsideFinderPassesThrough() {
    #expect(decide(event: cmd(KeyCode.x), context: ctx(finder: false)) == .passThrough)
}

@Test func pasteOutsideFinderPassesThrough() {
    #expect(decide(event: cmd(KeyCode.v), context: ctx(finder: false)) == .passThrough)
}

@Test func cutWithNoSelectionPassesThrough() {
    #expect(decide(event: cmd(KeyCode.x), context: ctx(selection: false)) == .passThrough)
}

@Test func cutInFinderWithSelectionCuts() {
    #expect(decide(event: cmd(KeyCode.x), context: ctx()) == .cut)
}

@Test func pasteWhenArmedAndIntactPastes() {
    #expect(decide(event: cmd(KeyCode.v), context: ctx()) == .paste)
}

// Guards the highest-severity failure mode: acting on a pasteboard we no longer own.
@Test func pasteWhenPasteboardChangedPassesThrough() {
    #expect(decide(event: cmd(KeyCode.v), context: ctx(intact: false)) == .passThrough)
}

@Test func pasteWhenNotArmedPassesThrough() {
    #expect(decide(event: cmd(KeyCode.v), context: ctx(armed: false)) == .passThrough)
}

@Test func controlXPassesThroughWhenSettingDisabled() {
    #expect(decide(event: ctrl(KeyCode.x), context: ctx(controlHotkeys: false)) == .passThrough)
}

@Test func controlXCutsWhenSettingEnabled() {
    #expect(decide(event: ctrl(KeyCode.x), context: ctx(controlHotkeys: true)) == .cut)
}

@Test func controlVPastesWhenSettingEnabled() {
    #expect(decide(event: ctrl(KeyCode.v), context: ctx(controlHotkeys: true)) == .paste)
}

// ⌘⇧X is a different shortcut and must never be swallowed.
@Test func commandShiftXPassesThrough() {
    let event = KeyEvent(keyCode: KeyCode.x, command: true, control: false, shift: true, option: false)
    #expect(decide(event: event, context: ctx()) == .passThrough)
}

// ⌥⌘V is Finder's own Move Item Here; users who type it directly must keep it.
@Test func optionCommandVPassesThrough() {
    let event = KeyEvent(keyCode: KeyCode.v, command: true, control: false, shift: false, option: true)
    #expect(decide(event: event, context: ctx()) == .passThrough)
}

@Test func controlCommandXPassesThrough() {
    let event = KeyEvent(keyCode: KeyCode.x, command: true, control: true, shift: false, option: false)
    #expect(decide(event: event, context: ctx(controlHotkeys: true)) == .passThrough)
}

@Test func unrelatedKeyPassesThrough() {
    #expect(decide(event: cmd(8), context: ctx()) == .passThrough)  // ⌘C
}

@Test func bareXPassesThrough() {
    let event = KeyEvent(keyCode: KeyCode.x, command: false, control: false, shift: false, option: false)
    #expect(decide(event: event, context: ctx()) == .passThrough)
}
