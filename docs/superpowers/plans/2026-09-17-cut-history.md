# Cut History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remember what was cut, and let the user paste any of it later — from a keyboard panel on `⌥⌘V` or from the status-bar menu — with Finder still performing every move.

**Architecture:** A pure `CutHistory` type in `CutXCore` holds the entries and is fully unit-tested. `HistoryStore` persists it as JSON in Application Support. Pasting an old entry writes its file URLs to the pasteboard and posts `⌥⌘V`, which a spike on 2026-09-17 proved Finder accepts as a genuine move. The whole feature is gated behind a single `Entitlements.hasPro` flag that returns `true` until the In-App Purchase exists, so the feature can ship and be tested before any paywall is built.

**Tech Stack:** Swift 6.4, SwiftPM, AppKit, `Codable` + `FileManager` for persistence, swift-testing.

## Global Constraints

- Everything testable without a keyboard, Finder, or a granted permission lives in `CutXCore`. `Sources/CutX` stays the thin, untestable shell.
- **The sandbox must keep working with no entitlement beyond `com.apple.security.app-sandbox`.** No Apple Events, no Automation prompt. This was the load-bearing App Store rejection; regressing it kills the store build.
- **Accessibility stays the only permission the app requests.**
- Run tests with `./scripts/test.sh`, never bare `swift test` (Command Line Tools, no Xcode). Linker warnings about CLT search paths are expected.
- Bundle identifier `com.helalrules.CutX`; team `T958VWM76Z`; direct builds sign with `Developer ID Application: Ahmed Helal (T958VWM76Z)`.
- Store builds compile with `-DAPPSTORE` via `CUTX_APPSTORE=1` and must contain no donation link.
- **Product name is `CutX`** in all user-facing copy.
- **Every new user-facing string goes into all eleven `Resources/<code>.lproj/Localizable.strings` files with identical keys.** A missing key renders the raw key name.
- Free tier is unchanged: the entire history is Pro.
- History is capped at **20 entries**. Older entries fall off the end.
- Existing tests must keep passing: 36 before this plan starts.
- **`./scripts/test.sh` builds the whole package, app target included.** So the app
  must always compile, even mid-plan. After Task 3 the app was unblocked with a
  `.showHistory` case in `HotkeyMonitor` and `historyEnabled: false` at both `Context`
  call sites in `main.swift`; Task 7 replaces the `false` with the real condition.
  If a task leaves the app target broken, the test suite cannot run at all.

## File Structure

| Path | Responsibility |
|---|---|
| `Sources/CutXCore/CutHistory.swift` | The entry type and the ordered collection. Pure logic, no I/O. |
| `Sources/CutXCore/Entitlements.swift` | `hasPro` — the single place the paywall is ever consulted. |
| `Sources/CutX/HistoryStore.swift` | Loads and saves the history as JSON under Application Support. |
| `Sources/CutX/HistoryPanel.swift` | The `⌥⌘V` panel: a borderless key window with a keyboard-driven list. |
| `Sources/CutX/main.swift` | Wires cut, paste and the panel to the history. |
| `Sources/CutX/MenuBarController.swift` | Adds the Recent submenu. |
| `Sources/CutX/FinderBridge.swift` | Gains `writeToPasteboard(_:)`. |
| `Sources/CutXCore/Decision.swift` | Gains the `.showHistory` decision for `⌥⌘V`. |
| `Tests/CutXCoreTests/CutHistoryTests.swift` | The collection's behaviour. |
| `Tests/CutXCoreTests/DecisionTests.swift` | Extended for `⌥⌘V`. |

---

### Task 1: `CutHistory` — the pure collection

**Files:**
- Create: `Sources/CutXCore/CutHistory.swift`
- Test: `Tests/CutXCoreTests/CutHistoryTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable` with `public let id: UUID`, `public var urls: [URL]`, `public let cutAt: Date`, `public var displayName: String`, `public var subtitle: String`, and `public init(urls: [URL], cutAt: Date = Date())`.
  - `public struct CutHistory: Codable, Equatable, Sendable` with `public static let limit = 20`, `public init()`, `public private(set) var entries: [HistoryEntry]`, `public mutating func record(_ urls: [URL], at: Date = Date())`, `public mutating func updatePaths(id: UUID, to: [URL])`, `public mutating func remove(id: UUID)`, `public mutating func clear()`, `public func entry(at index: Int) -> HistoryEntry?`.

- [ ] **Step 1: Write the failing tests**

`Tests/CutXCoreTests/CutHistoryTests.swift`:
```swift
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

// A group has to be recognisable at a glance in a list, so it names its first
// item and says how many more came with it.
@Test func groupNamesFirstItemAndCounts() {
    var h = CutHistory()
    h.record([url("a.txt"), url("b.txt"), url("c.txt")])
    #expect(h.entries[0].displayName == "a.txt + 2 more")
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh 2>&1 | tail -20`
Expected: compile failure — `cannot find 'CutHistory' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/CutXCore/CutHistory.swift`:
```swift
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

    /// What the list shows. A group names its first item and says how many came
    /// with it, so a row is recognisable without expanding anything.
    public var displayName: String {
        guard let first = urls.first else { return "" }
        let name = first.lastPathComponent
        return urls.count == 1 ? name : "\(name) + \(urls.count - 1) more"
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh 2>&1 | tail -5`
Expected: `49 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutXCore/CutHistory.swift Tests/CutXCoreTests/CutHistoryTests.swift
git commit -m "feat: add CutHistory, the pure recent-cuts collection

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `Entitlements` — one place the paywall is consulted

Written now, before any In-App Purchase exists, so the rest of the feature is built against the final shape. `hasPro` returns `true` until the purchase is implemented, which means the feature can be developed and tested end to end without a paywall in the way.

**Files:**
- Create: `Sources/CutXCore/Entitlements.swift`
- Test: `Tests/CutXCoreTests/EntitlementsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public enum Entitlements` with `public static var hasPro: Bool`, `public static var isProBuild: Bool`, and `public static var proOverrideForTesting: Bool?`.

- [ ] **Step 1: Write the failing tests**

`Tests/CutXCoreTests/EntitlementsTests.swift`:
```swift
import Testing
@testable import CutXCore

// Until the In-App Purchase exists, Pro is on for everyone. This test is the
// reminder to change it deliberately rather than by accident.
@Test func proIsOpenUntilThePurchaseExists() {
    Entitlements.proOverrideForTesting = nil
    #expect(Entitlements.hasPro == true)
}

@Test func theOverrideWins() {
    Entitlements.proOverrideForTesting = false
    #expect(Entitlements.hasPro == false)
    Entitlements.proOverrideForTesting = true
    #expect(Entitlements.hasPro == true)
    Entitlements.proOverrideForTesting = nil
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh 2>&1 | tail -20`
Expected: `cannot find 'Entitlements' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/CutXCore/Entitlements.swift`:
```swift
import Foundation

/// The single place the app asks whether the user has Pro.
///
/// Every Pro feature routes through `hasPro` and nothing else, so when the
/// In-App Purchase is added there is exactly one function to change, and no
/// feature can accidentally forget the check.
///
/// It returns `true` today: the purchase does not exist yet, and shipping the
/// feature open lets it be tested and used before any paywall is built.
public enum Entitlements {
    /// Set by tests to exercise both sides of the gate. Never set in the app.
    public static var proOverrideForTesting: Bool?

    public static var hasPro: Bool {
        if let override = proOverrideForTesting { return override }
        return true
    }

    /// True in App Store builds, where a purchase is possible at all.
    public static var isProBuild: Bool {
        #if APPSTORE
        return true
        #else
        return false
        #endif
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh 2>&1 | tail -5`
Expected: `51 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutXCore/Entitlements.swift Tests/CutXCoreTests/EntitlementsTests.swift
git commit -m "feat: add Entitlements, the single Pro gate

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `⌥⌘V` joins the decision function

**Files:**
- Modify: `Sources/CutXCore/Decision.swift`
- Test: `Tests/CutXCoreTests/DecisionTests.swift`

**Interfaces:**
- Consumes: `Decision`, `KeyEvent`, `Context`, `KeyCode` (existing).
- Produces: a new `Decision` case `.showHistory`, and `Context` gains `public let historyEnabled: Bool` as the **last** initialiser parameter with no default.

**Note on an existing test:** `optionCommandVPassesThrough` currently asserts that `⌥⌘V` is passed through. That test is replaced here — the key now opens the panel when history is enabled, and still passes through when it is not.

- [ ] **Step 1: Update the existing test helper and add the new tests**

In `Tests/CutXCoreTests/DecisionTests.swift`, change the `ctx` helper to carry the new field:
```swift
private func ctx(
    finder: Bool = true,
    selection: Bool = true,
    armed: Bool = true,
    intact: Bool = true,
    controlHotkeys: Bool = false,
    history: Bool = true
) -> Context {
    Context(
        finderFrontmost: finder,
        hasSelection: selection,
        isArmed: armed,
        pasteboardIntact: intact,
        controlHotkeysEnabled: controlHotkeys,
        historyEnabled: history
    )
}
```

Replace the `optionCommandVPassesThrough` test with:
```swift
@Test func optionCommandVOpensHistory() {
    let event = KeyEvent(keyCode: KeyCode.v, command: true, control: false, shift: false, option: true)
    #expect(decide(event: event, context: ctx()) == .showHistory)
}

// Without Pro the key must do what it always did in Finder: Move Item Here.
@Test func optionCommandVPassesThroughWithoutHistory() {
    let event = KeyEvent(keyCode: KeyCode.v, command: true, control: false, shift: false, option: true)
    #expect(decide(event: event, context: ctx(history: false)) == .passThrough)
}

@Test func optionCommandVOutsideFinderPassesThrough() {
    let event = KeyEvent(keyCode: KeyCode.v, command: true, control: false, shift: false, option: true)
    #expect(decide(event: event, context: ctx(finder: false)) == .passThrough)
}

// The panel is about pasting; there is nothing to show when nothing was cut.
@Test func optionCommandVWithEmptyHistoryPassesThrough() {
    let event = KeyEvent(keyCode: KeyCode.v, command: true, control: false, shift: false, option: true)
    #expect(decide(event: event, context: ctx(armed: false, history: false)) == .passThrough)
}

@Test func optionCommandXIsNotHistory() {
    let event = KeyEvent(keyCode: KeyCode.x, command: true, control: false, shift: false, option: true)
    #expect(decide(event: event, context: ctx()) == .passThrough)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./scripts/test.sh 2>&1 | tail -20`
Expected: `extra argument 'historyEnabled' in call` and `type 'Decision' has no member 'showHistory'`.

- [ ] **Step 3: Update `Decision.swift`**

Add the case to the enum:
```swift
    /// Suppress the event; open the history panel.
    case showHistory
```

Add the field to `Context`, as the last stored property and last initialiser parameter:
```swift
    public let historyEnabled: Bool
```
```swift
    public init(
        finderFrontmost: Bool,
        hasSelection: Bool,
        isArmed: Bool,
        pasteboardIntact: Bool,
        controlHotkeysEnabled: Bool,
        historyEnabled: Bool
    ) {
        self.finderFrontmost = finderFrontmost
        self.hasSelection = hasSelection
        self.isArmed = isArmed
        self.pasteboardIntact = pasteboardIntact
        self.controlHotkeysEnabled = controlHotkeysEnabled
        self.historyEnabled = historyEnabled
    }
```

In `decide`, the guard currently rejects any event carrying Option. Replace the opening guard with a check that lets exactly `⌥⌘V` through to a new branch:

```swift
public func decide(event: KeyEvent, context: Context) -> Decision {
    // ⌥⌘V is Finder's Move Item Here. CutX claims it only to show history, and
    // only in Finder with something to show; otherwise Finder keeps it.
    if event.option, event.command, !event.control, !event.shift, event.keyCode == KeyCode.v {
        return (context.finderFrontmost && context.historyEnabled) ? .showHistory : .passThrough
    }

    // Any other extra modifier means a different shortcut. Never claim it.
    guard !event.shift, !event.option else { return .passThrough }
```

The rest of the function is unchanged.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh 2>&1 | tail -5`
Expected: `55 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutXCore/Decision.swift Tests/CutXCoreTests/DecisionTests.swift
git commit -m "feat: claim Option-Command-V for the history panel

Only in Finder and only when history is enabled; Finder keeps Move Item
Here in every other case.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `HistoryStore` — persistence

**Files:**
- Create: `Sources/CutX/HistoryStore.swift`

**Interfaces:**
- Consumes: `CutHistory` (Task 1).
- Produces: `final class HistoryStore` with `init()`, `var history: CutHistory` (writing it schedules a save), `func save()`, and `static var fileURL: URL`.

This lives in `Sources/CutX` rather than `CutXCore` because it touches the file system; `CutHistory` stays pure and fully tested.

- [ ] **Step 1: Write the implementation**

`Sources/CutX/HistoryStore.swift`:
```swift
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
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | grep -vE "ld: warning" | tail -3`
Expected: `Build complete`.

- [ ] **Step 3: Commit**

```bash
git add Sources/CutX/HistoryStore.swift
git commit -m "feat: persist cut history as JSON in Application Support

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Pasting an old entry

**Files:**
- Modify: `Sources/CutX/FinderBridge.swift`
- Modify: `Sources/CutX/main.swift`

**Interfaces:**
- Consumes: `FinderBridge.sendMoveItemHere()`, `HistoryStore` (Task 4), `CutHistory` (Task 1).
- Produces: `FinderBridge.writeToPasteboard(_ urls: [URL]) -> Int` returning the resulting `changeCount`; `AppDelegate.pasteFromHistory(entryID:)`.

**Why this works:** by the time an old entry is pasted, Finder's own copy is long gone from the pasteboard. CutX writes the file URLs itself and posts `⌥⌘V`. A spike on 2026-09-17 confirmed Finder accepts a third-party pasteboard and performs a genuine move — the source file was gone afterwards — so undo, the progress window and conflict dialogs still come from Finder.

- [ ] **Step 1: Add `writeToPasteboard` to `FinderBridge.swift`**

Add after `pasteboardFileURLs()`:
```swift
    /// Puts file URLs on the pasteboard in the form Finder's Move Item Here
    /// accepts, and returns the new changeCount.
    ///
    /// Verified 2026-09-17: Finder treats a pasteboard written by another app
    /// exactly as it treats its own, so the move stays Finder's work.
    @discardableResult
    static func writeToPasteboard(_ urls: [URL]) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
        return pasteboard.changeCount
    }
```

- [ ] **Step 2: Wire the history into cut and paste in `main.swift`**

Add the property next to `private var state = CutState()`:
```swift
    private let historyStore = HistoryStore()
```

In `performCut()`, inside the block that arms the state (immediately after `state.arm(items:changeCount:)`), record the cut:
```swift
            self.historyStore.history.record(urls)
```

Replace `performPaste()` entirely, so a normal paste also updates where the entry now lives:
```swift
    private func performPaste() {
        // Remember what is about to move and where it is going, so the history
        // entry can be re-pointed at the new location after Finder is done.
        let moved = state.items
        let destination = FinderBridge.frontmostFinderDirectory()

        FinderBridge.sendMoveItemHere()
        state.clear()
        menuBar?.update(names: [])
        sounds.playPaste()

        guard let destination,
              let entry = historyStore.history.entries.first(where: { $0.urls == moved })
        else { return }
        historyStore.history.updatePaths(
            id: entry.id,
            to: moved.map { destination.appendingPathComponent($0.lastPathComponent) }
        )
    }

    /// Pastes an entry the user picked from history. The pasteboard no longer
    /// holds it, so CutX writes it back before asking Finder to move.
    func pasteFromHistory(entryID: UUID) {
        guard let entry = historyStore.history.entries.first(where: { $0.id == entryID }) else { return }
        let changeCount = FinderBridge.writeToPasteboard(entry.urls)
        state.arm(items: entry.urls, changeCount: changeCount)
        menuBar?.update(names: state.displayNames)
        performPaste()
    }
```

- [ ] **Step 3: Add `frontmostFinderDirectory` to `FinderBridge.swift`**

The destination cannot be asked of Finder over Apple Events — that is the whole reason for the current architecture. It comes from the frontmost window's proxy icon via the Accessibility API, which CutX is already trusted for.

```swift
    /// The folder shown in the frontmost Finder window, read from the window's
    /// Accessibility document attribute. Apple Events are not an option here:
    /// removing them is what made the sandboxed build possible at all.
    ///
    /// Returns nil when Finder has no window (the Desktop), which simply means
    /// the history entry keeps its old path.
    static func frontmostFinderDirectory() -> URL? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }) else { return nil }

        let element = AXUIElementCreateApplication(app.processIdentifier)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let window = windowValue
        else { return nil }

        var documentValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXDocumentAttribute as CFString, &documentValue) == .success,
              let path = documentValue as? String,
              let url = URL(string: path)
        else { return nil }

        return url.isFileURL ? url : nil
    }
```

Add `import ApplicationServices` at the top of `FinderBridge.swift` if it is not already there.

- [ ] **Step 4: Build and confirm the tests still pass**

Run: `swift build 2>&1 | grep -E "error" | head -5; ./scripts/test.sh 2>&1 | grep -E "Test run with|error:"`
Expected: no errors, `55 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutX/FinderBridge.swift Sources/CutX/main.swift
git commit -m "feat: record cuts in history and paste old entries back

Pasting an old entry writes its file URLs to the pasteboard and posts
Move Item Here, so Finder still performs the move and undo still works.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: The Recent submenu

**Files:**
- Modify: `Sources/CutX/MenuBarController.swift`
- Modify: `Sources/CutX/main.swift`
- Modify: all eleven `Resources/<code>.lproj/Localizable.strings`

**Interfaces:**
- Consumes: `CutHistory`, `HistoryEntry`, `Entitlements`.
- Produces: `MenuBarController.onPasteHistory: (UUID) -> Void`, `MenuBarController.onClearHistory: () -> Void`, and `MenuBarController.update(names:history:)` replacing `update(names:)`.

- [ ] **Step 1: Add the strings to English**

Append to `Resources/en.lproj/Localizable.strings`:
```
/* Cut history */
"history.recent" = "Recent";
"history.empty" = "Nothing cut yet";
"history.clear" = "Clear history";
"history.title" = "Recent cuts";
"history.hint" = "Pick a number, or use the arrow keys. Return pastes.";
```

Then add the same five keys to the other ten files with these values:

| file | recent | empty | clear | title | hint |
|---|---|---|---|---|---|
| `ar` | `الأخيرة` | `لم تقص شيئًا بعد` | `مسح السجل` | `آخر ما قصصته` | `اختر رقمًا أو استخدم الأسهم. Return يلصق.` |
| `es` | `Recientes` | `Nada cortado aún` | `Borrar historial` | `Cortes recientes` | `Elige un número o usa las flechas. Intro pega.` |
| `fr` | `Récents` | `Rien de coupé pour l'instant` | `Effacer l'historique` | `Coupes récentes` | `Choisissez un numéro ou utilisez les flèches. Retour colle.` |
| `de` | `Zuletzt` | `Noch nichts ausgeschnitten` | `Verlauf löschen` | `Zuletzt ausgeschnitten` | `Zahl wählen oder Pfeiltasten. Return setzt ein.` |
| `pt-BR` | `Recentes` | `Nada recortado ainda` | `Limpar histórico` | `Recortes recentes` | `Escolha um número ou use as setas. Return cola.` |
| `ru` | `Недавние` | `Пока ничего не вырезано` | `Очистить историю` | `Недавние вырезки` | `Выберите номер или стрелки. Return вставляет.` |
| `zh-Hans` | `最近` | `还没有剪切任何内容` | `清除历史` | `最近剪切` | `选择数字或使用方向键，Return 粘贴。` |
| `ja` | `最近の項目` | `まだ何もカットしていません` | `履歴を消去` | `最近のカット` | `番号か矢印キーで選び、Return で貼り付け。` |
| `tr` | `Son kesilenler` | `Henüz bir şey kesilmedi` | `Geçmişi temizle` | `Son kesmeler` | `Bir numara seçin veya ok tuşlarını kullanın. Return yapıştırır.` |
| `it` | `Recenti` | `Ancora niente tagliato` | `Cancella cronologia` | `Tagli recenti` | `Scegli un numero o usa le frecce. Invio incolla.` |

Verify every file has the same keys:
```bash
for f in en ar es fr de pt-BR ru zh-Hans ja tr it; do
  diff <(grep -o '^"[^"]*"' Resources/en.lproj/Localizable.strings) \
       <(grep -o '^"[^"]*"' Resources/$f.lproj/Localizable.strings) >/dev/null \
    && echo "  $f ok" || echo "  $f MISMATCH"
done
```
Expected: all eleven `ok`.

- [ ] **Step 2: Add the submenu to `MenuBarController.swift`**

Add the closures next to `onClear`:
```swift
    var onPasteHistory: (UUID) -> Void = { _ in }
    var onClearHistory: () -> Void = {}
```

Add the stored history next to `private var names: [String] = []`:
```swift
    private var history: [HistoryEntry] = []
```

Replace `update(names:)` with:
```swift
    func update(names: [String], history: [HistoryEntry] = []) {
        self.names = names
        self.history = history
        rebuild()
    }
```

In `buildMenu()`, insert before the `menu.addItem(.separator())` that precedes "Open CutX":
```swift
        if Entitlements.hasPro {
            menu.addItem(.separator())
            menu.addItem(historyMenuItem())
        }
```

Add the builder alongside the other private methods:
```swift
    /// The recent cuts, as a submenu. Selecting one pastes it into the frontmost
    /// Finder window, exactly as the panel does.
    private func historyMenuItem() -> NSMenuItem {
        let submenu = NSMenu()

        if history.isEmpty {
            let empty = NSMenuItem(title: T("history.empty"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for entry in history.prefix(10) {
                let item = NSMenuItem(
                    title: entry.displayName,
                    action: #selector(historyPicked(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = entry.id
                item.toolTip = entry.subtitle
                submenu.addItem(item)
            }
            submenu.addItem(.separator())
            submenu.addItem(item(T("history.clear"), #selector(clearHistoryTapped)))
        }

        let parent = NSMenuItem(title: T("history.recent"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    @objc private func historyPicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onPasteHistory(id)
    }

    @objc private func clearHistoryTapped() { onClearHistory() }
```

- [ ] **Step 3: Wire it in `main.swift`**

In `applicationDidFinishLaunching`, after `menuBar.onOpenWindow = ...`:
```swift
        menuBar.onPasteHistory = { [weak self] id in self?.pasteFromHistory(entryID: id) }
        menuBar.onClearHistory = { [weak self] in
            self?.historyStore.history.clear()
            self?.refreshMenuBar()
        }
```

Add a helper next to `clearCut()`, and use it everywhere `menuBar?.update(names:)` is currently called:
```swift
    private func refreshMenuBar() {
        menuBar?.update(names: state.displayNames, history: historyStore.history.entries)
    }
```

Replace all three existing `menuBar?.update(names: [])` and `menuBar?.update(names: state.displayNames)` calls with `refreshMenuBar()`.

- [ ] **Step 4: Build, test, and check by hand**

Run: `pkill -x CutX; ./scripts/build-app.sh && ./scripts/test.sh 2>&1 | grep "Test run with" && open dist/CutX.app`

Expected: right-clicking the menu-bar icon shows a **Recent** submenu. Cut a file, and it appears there. Pick it from another folder and it moves. Quit and relaunch: the entry is still listed.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutX Resources
git commit -m "feat: add the Recent submenu to the status bar

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Correction, 2026-09-17 — Task 5's premise was wrong, and what replaces it

**The spike that justified Task 5 was measuring stale state.** It wrote file URLs
to the pasteboard, posted ⌥⌘V, and the file moved — so the plan concluded Finder
accepts a third-party pasteboard. It does not. The pasteboard still carried
`com.apple.finder.noderef` from a Finder copy earlier in that session, and that is
what Move Item Here actually consumes. With the pasteboard properly emptied first,
the same experiment fails every time, whether CutX is running or not.

Three wrong diagnoses were reached before the measurement was made correctly:
that CutX was swallowing its own synthetic keystroke (the marker works — proved by
logging the tap), that the app being alive was the variable (killing it changed
nothing), and that our pasteboard types were sufficient (they are not).

**What does work, verified end to end:**

```
NSWorkspace.activateFileViewerSelecting(urls)   → Finder selects the files
synthetic ⌘C                                    → Finder writes its own pasteboard,
                                                   noderef included
synthetic ⌥⌘V                                   → a genuine move; source gone
```

`activateFileViewerSelecting` is a plain `NSWorkspace` call — **no Apple Events, no
Automation permission** — so the sandboxed App Store build is unaffected. Finder
still performs every move, so undo, progress and conflict dialogs are unchanged.
Note the second step must be ⌘C, not ⌘X: Finder's Cut is permanently disabled and
produces nothing.

### Task 7 (revised): the history entry opens a stack, not a blind paste

Decided with Ahmed on 2026-09-17, and better than the original panel: clicking an
entry opens a small stack showing **where the files were** and **where they went**,
with actions on hover:

- **Cut these files** — reveal-and-select in Finder, synthetic ⌘C, then arm CutX
  exactly as a real ⌘X does. The user then pastes wherever they like, with the
  normal ⌘V. This is why the approach is sound: the pasteboard is Finder's own.
- **Copy these files** — the same, without arming; a plain Finder copy.
- **Put them back** — move them to the location the entry was cut from, which the
  history already records.

This turns history from a blind paste into a small control panel for a past cut,
and it sidesteps the pasteboard problem entirely rather than fighting it.

The old panel design (number keys, arrows, Return pastes) is superseded. Task 7's
original content below is kept for reference but must not be implemented as written.

#### Task 7a — the entry remembers where it came from

`HistoryEntry` stores `urls`, which start at the origin and are re-pointed to the
destination after a paste. "Put them back" needs the origin kept separately.

**Files:** `Sources/CutXCore/CutHistory.swift`, `Tests/CutXCoreTests/CutHistoryTests.swift`

**Produces:** `HistoryEntry.origin: URL` (the folder the files were cut from, fixed
for the entry's life) and `HistoryEntry.hasMoved: Bool` (true once `urls` no longer
sit in `origin`).

- [ ] **Step 1: Add the failing tests**

Append to `Tests/CutXCoreTests/CutHistoryTests.swift`:
```swift
@Test func recordsWhereTheFilesCameFrom() {
    var h = CutHistory()
    h.record([url("a.txt")])
    #expect(h.entries[0].origin.path == "/Users/x")
    #expect(h.entries[0].hasMoved == false)
}

// The origin is the whole point of "put them back", so a paste must not overwrite it.
@Test func originSurvivesAPaste() {
    var h = CutHistory()
    h.record([url("a.txt")])
    let id = h.entries[0].id
    h.updatePaths(id: id, to: [URL(fileURLWithPath: "/Users/x/Archive/a.txt")])
    #expect(h.entries[0].origin.path == "/Users/x")
    #expect(h.entries[0].urls.first?.path == "/Users/x/Archive/a.txt")
    #expect(h.entries[0].hasMoved == true)
}

// Moving something back to where it started makes the entry inert again.
@Test func movingBackToOriginClearsHasMoved() {
    var h = CutHistory()
    h.record([url("a.txt")])
    let id = h.entries[0].id
    h.updatePaths(id: id, to: [URL(fileURLWithPath: "/Users/x/Archive/a.txt")])
    h.updatePaths(id: id, to: [url("a.txt")])
    #expect(h.entries[0].hasMoved == false)
}
```

- [ ] **Step 2: Run and confirm they fail**

Run: `./scripts/test.sh 2>&1 | tail -20`
Expected: `value of type 'HistoryEntry' has no member 'origin'`.

- [ ] **Step 3: Implement**

In `HistoryEntry`, add the stored property after `cutAt`:
```swift
    /// The folder the files were cut from. Fixed for the entry's life: it is what
    /// "put them back" means, so a paste must never overwrite it.
    public let origin: URL
```

Set it in `init`, after `self.cutAt = cutAt`:
```swift
        self.origin = urls.first?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/")
```

Add after `subtitle`:
```swift
    /// True once the files no longer sit where they were cut from.
    public var hasMoved: Bool {
        urls.first?.deletingLastPathComponent() != origin
    }
```

- [ ] **Step 4: Run and confirm they pass**

Run: `./scripts/test.sh 2>&1 | tail -5`
Expected: `59 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutXCore/CutHistory.swift Tests/CutXCoreTests/CutHistoryTests.swift
git commit -m "feat: history entries remember where they were cut from

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

#### Task 7b — `FinderBridge` gains the three actions

**Files:** `Sources/CutX/FinderBridge.swift`

**Produces:** `static func selectInFinder(_ urls: [URL])`, `static func recopy(_ urls: [URL], then: @escaping (Int) -> Void)`.

- [ ] **Step 1: Add both functions**

Append inside `enum FinderBridge`:
```swift
    /// Reveals the files in Finder with them selected.
    ///
    /// `activateFileViewerSelecting` is a plain NSWorkspace call: no Apple Events
    /// and no Automation permission, so the sandboxed App Store build is
    /// unaffected. This is what makes re-cutting an old entry possible at all.
    static func selectInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Selects the files in Finder and has Finder copy them, so the pasteboard
    /// ends up carrying Finder's own data — `com.apple.finder.noderef` included.
    ///
    /// That type is what Move Item Here actually consumes, and only Finder can
    /// write it. Writing file URLs ourselves is not equivalent: it looks correct
    /// and silently does nothing. Verified 2026-09-17.
    ///
    /// Note it must be ⌘C, not ⌘X: Finder's Cut is permanently disabled.
    static func recopy(_ urls: [URL], then completion: @escaping (Int) -> Void) {
        let before = NSPasteboard.general.changeCount
        selectInFinder(urls)
        // Finder needs a moment to bring the window forward and apply the
        // selection before the keystroke means anything.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            sendCopy()
            awaitChange(since: before, deadline: Date().addingTimeInterval(1.0), then: completion)
        }
    }

    private static func awaitChange(since before: Int, deadline: Date, then completion: @escaping (Int) -> Void) {
        let now = NSPasteboard.general.changeCount
        if now != before { completion(now); return }
        guard Date() < deadline else { completion(before); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            awaitChange(since: before, deadline: deadline, then: completion)
        }
    }
```

- [ ] **Step 2: Build**

Run: `swift build 2>&1 | grep -E "error" | head -3`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add Sources/CutX/FinderBridge.swift
git commit -m "feat: re-cut an old selection through Finder's own copy

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

#### Task 7c — the three actions in `main.swift`

**Files:** `Sources/CutX/main.swift`

**Produces:** `func cutFromHistory(entryID:)`, `func copyFromHistory(entryID:)`, `func putBack(entryID:)`.

- [ ] **Step 1: Replace `pasteFromHistory(entryID:)` with the three actions**

```swift
    /// Re-cuts an old entry: Finder selects and copies the files, then CutX arms
    /// itself exactly as a real ⌘X would. The user pastes wherever they like.
    func cutFromHistory(entryID: UUID) {
        guard let entry = historyStore.history.entries.first(where: { $0.id == entryID }) else { return }
        FinderBridge.recopy(entry.urls) { [weak self] changeCount in
            guard let self else { return }
            self.state.arm(items: entry.urls, changeCount: changeCount)
            self.refreshMenuBar()
            self.sounds.playCut()
            self.hud.show(count: entry.urls.count)
        }
    }

    /// Copies an old entry without arming: a plain Finder copy, so ⌘V duplicates
    /// rather than moves.
    func copyFromHistory(entryID: UUID) {
        guard let entry = historyStore.history.entries.first(where: { $0.id == entryID }) else { return }
        FinderBridge.recopy(entry.urls) { _ in }
    }

    /// Moves the files back to the folder they were cut from. Finder performs the
    /// move, so this is undoable like any other.
    func putBack(entryID: UUID) {
        guard let entry = historyStore.history.entries.first(where: { $0.id == entryID }),
              entry.hasMoved else { return }
        let origin = entry.origin
        FinderBridge.recopy(entry.urls) { [weak self] changeCount in
            guard let self else { return }
            self.state.arm(items: entry.urls, changeCount: changeCount)
            FinderBridge.openFolder(origin)
            // Give Finder time to show the destination before asking it to move.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performPaste()
            }
        }
    }
```

- [ ] **Step 2: Add `openFolder` to `FinderBridge.swift`**

```swift
    /// Opens a folder in Finder and brings it forward, so the next Move Item Here
    /// lands there.
    static func openFolder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
```

- [ ] **Step 3: Build and test**

Run: `swift build 2>&1 | grep error | head -3; ./scripts/test.sh 2>&1 | grep "Test run with"`
Expected: no errors, `59 tests passed`.

- [ ] **Step 4: Commit**

```bash
git add Sources/CutX
git commit -m "feat: cut, copy and put back an entry from history

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

#### Task 7d — the stack UI

Clicking a history entry opens a small panel showing where the files were, where
they are now, and the three actions. Replaces the superseded ⌥⌘V list.

**Files:** `Sources/CutX/HistoryStack.swift`, `Sources/CutX/MenuBarController.swift`, `Sources/CutX/main.swift`, all eleven `.lproj` files.

**New strings** (add to all eleven; English shown):
```
"stack.from" = "From";
"stack.now" = "Now in";
"stack.cut" = "Cut these";
"stack.copy" = "Copy these";
"stack.putBack" = "Put them back";
```

Translations: `ar` = من · الآن في · اقص هذه · انسخ هذه · أعدها لمكانها ·
`es` = Desde · Ahora en · Cortar · Copiar · Devolver ·
`fr` = Depuis · Maintenant dans · Couper · Copier · Remettre ·
`de` = Von · Jetzt in · Ausschneiden · Kopieren · Zurücklegen ·
`pt-BR` = De · Agora em · Recortar · Copiar · Devolver ·
`ru` = Откуда · Сейчас в · Вырезать · Копировать · Вернуть ·
`zh-Hans` = 来自 · 现在位于 · 剪切 · 复制 · 放回原处 ·
`ja` = 元の場所 · 現在の場所 · カット · コピー · 元に戻す ·
`tr` = Nereden · Şimdi · Kes · Kopyala · Geri koy ·
`it` = Da · Ora in · Taglia · Copia · Rimetti a posto

- [ ] **Step 1: Write `Sources/CutX/HistoryStack.swift`**

```swift
import AppKit
import CutXCore

/// The panel a history entry opens: where the files were, where they are now, and
/// what can be done with them. A blind "paste this" was the original design and it
/// could not work — Finder will not move a pasteboard it did not write — so the
/// entry became a small control panel instead, which is more useful anyway.
final class HistoryStack {
    private var panel: NSPanel?
    private let onCut: (UUID) -> Void
    private let onCopy: (UUID) -> Void
    private let onPutBack: (UUID) -> Void

    init(
        onCut: @escaping (UUID) -> Void,
        onCopy: @escaping (UUID) -> Void,
        onPutBack: @escaping (UUID) -> Void
    ) {
        self.onCut = onCut
        self.onCopy = onCopy
        self.onPutBack = onPutBack
    }

    func show(entry: HistoryEntry, near point: NSPoint) {
        hide()

        let width: CGFloat = 340
        let height: CGFloat = entry.hasMoved ? 214 : 178

        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true

        var y = height - 34

        let title = NSTextField(labelWithString: MenuBarController.label(for: entry))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingMiddle
        title.frame = NSRect(x: 16, y: y, width: width - 32, height: 18)
        background.addSubview(title)
        y -= 30

        addRow(to: background, label: T("stack.from"), value: entry.origin.path, y: &y, width: width)
        if entry.hasMoved {
            addRow(to: background, label: T("stack.now"), value: entry.subtitle, y: &y, width: width)
        }

        y -= 10
        addButton(to: background, title: T("stack.cut"), y: &y, width: width, prominent: true) { [weak self] in
            self?.hide(); self?.onCut(entry.id)
        }
        addButton(to: background, title: T("stack.copy"), y: &y, width: width, prominent: false) { [weak self] in
            self?.hide(); self?.onCopy(entry.id)
        }
        if entry.hasMoved {
            addButton(to: background, title: T("stack.putBack"), y: &y, width: width, prominent: false) { [weak self] in
                self?.hide(); self?.onPutBack(entry.id)
            }
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: clamped(point, size: NSSize(width: width, height: height)),
                                size: NSSize(width: width, height: height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = background
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.orderFrontRegardless()
        self.panel = panel

        L10n.applyDirection(to: background)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func addRow(to view: NSView, label: String, value: String, y: inout CGFloat, width: CGFloat) {
        let caption = NSTextField(labelWithString: label)
        caption.font = .systemFont(ofSize: 10, weight: .semibold)
        caption.textColor = .tertiaryLabelColor
        caption.frame = NSRect(x: 16, y: y + 14, width: width - 32, height: 13)
        view.addSubview(caption)

        let path = NSTextField(labelWithString: value)
        path.font = .systemFont(ofSize: 11)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingHead
        path.frame = NSRect(x: 16, y: y, width: width - 32, height: 14)
        view.addSubview(path)
        y -= 36
    }

    private func addButton(
        to view: NSView, title: String, y: inout CGFloat, width: CGFloat,
        prominent: Bool, action: @escaping () -> Void
    ) {
        let button = ActionButton(title: title, action: action)
        button.bezelStyle = .rounded
        if prominent { button.keyEquivalent = "\r" }
        button.frame = NSRect(x: 16, y: y, width: width - 32, height: 26)
        view.addSubview(button)
        y -= 30
    }

    /// Keeps the panel fully on screen wherever the pointer happens to be.
    private func clamped(_ point: NSPoint, size: NSSize) -> NSPoint {
        var origin = NSPoint(x: point.x - size.width / 2, y: point.y - size.height - 8)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            origin.x = min(max(origin.x, frame.minX + 8), frame.maxX - size.width - 8)
            origin.y = min(max(origin.y, frame.minY + 8), frame.maxY - size.height - 8)
        }
        return origin
    }
}

/// A button that owns its closure, so the panel does not need a target object per
/// action.
private final class ActionButton: NSButton {
    private let handler: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.handler = action
        super.init(frame: .zero)
        self.title = title
        self.target = self
        self.action = #selector(fire)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { handler() }
}
```

- [ ] **Step 2: Open the stack from the menu**

In `MenuBarController.swift`, replace `onPasteHistory` with:
```swift
    var onOpenStack: (UUID) -> Void = { _ in }
```
and in `historyPicked`:
```swift
        onOpenStack(id)
```

- [ ] **Step 3: Wire the three actions in `main.swift`**

Replace the `menuBar.onPasteHistory = ...` line with:
```swift
        menuBar.onOpenStack = { [weak self] id in
            guard let self,
                  let entry = self.historyStore.history.entries.first(where: { $0.id == id })
            else { return }
            self.historyStack.show(entry: entry, near: NSEvent.mouseLocation)
        }
```
and add the property:
```swift
    private lazy var historyStack = HistoryStack(
        onCut: { [weak self] in self?.cutFromHistory(entryID: $0) },
        onCopy: { [weak self] in self?.copyFromHistory(entryID: $0) },
        onPutBack: { [weak self] in self?.putBack(entryID: $0) }
    )
```

- [ ] **Step 4: Build and check by hand**

Run: `pkill -x CutX; ./scripts/build-app.sh && ./scripts/test.sh 2>&1 | grep "Test run with" && open dist/CutX.app`

Expected: picking an entry from Recent opens a small panel showing **From** and,
once it has moved, **Now in**, with **Cut these**, **Copy these** and **Put them
back**. Each action works and `⌘Z` undoes the resulting move.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutX Resources
git commit -m "feat: a history entry opens a stack with cut, copy and put back

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7 (superseded): The `⌥⌘V` panel

**Files:**
- Create: `Sources/CutX/HistoryPanel.swift`
- Modify: `Sources/CutX/main.swift`, `Sources/CutX/HotkeyMonitor.swift`

**Interfaces:**
- Consumes: `HistoryEntry`, `L10n`.
- Produces: `final class HistoryPanel` with `init(onPick: @escaping (UUID) -> Void)`, `func show(entries: [HistoryEntry])`, `func hide()`, `var isVisible: Bool`.

- [ ] **Step 1: Write `Sources/CutX/HistoryPanel.swift`**

```swift
import AppKit
import CutXCore

/// The ⌥⌘V panel: a floating list of recent cuts, driven entirely from the
/// keyboard. Number keys jump straight to an entry, arrows move, Return pastes,
/// Escape dismisses. Someone reaching for ⌥⌘V already has both hands on the
/// keyboard; making them grab the mouse would defeat the point.
final class HistoryPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var panel: NSPanel?
    private var table: NSTableView?
    private var entries: [HistoryEntry] = []
    private var monitor: Any?
    private let onPick: (UUID) -> Void

    init(onPick: @escaping (UUID) -> Void) {
        self.onPick = onPick
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(entries: [HistoryEntry]) {
        guard !entries.isEmpty else { return }
        self.entries = entries
        hide()

        let width: CGFloat = 420
        let rowHeight: CGFloat = 38
        let headerHeight: CGFloat = 64
        let visibleRows = min(entries.count, 8)
        let height = headerHeight + CGFloat(visibleRows) * rowHeight

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        panel.contentView = background

        let title = NSTextField(labelWithString: T("history.title"))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 16, y: height - 28, width: width - 32, height: 18)
        background.addSubview(title)

        let hint = NSTextField(labelWithString: T("history.hint"))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 16, y: height - 48, width: width - 32, height: 16)
        background.addSubview(hint)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height - headerHeight))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true

        let table = NSTableView()
        table.headerView = nil
        table.rowHeight = rowHeight
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.dataSource = self
        table.delegate = self
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("entry"))
        column.width = width
        table.addTableColumn(column)
        scroll.documentView = table
        background.addSubview(scroll)
        self.table = table

        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - width / 2,
                y: frame.midY - height / 2
            ))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        L10n.applyDirection(to: background)
        installKeyMonitor()
    }

    func hide() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        panel?.orderOut(nil)
        panel = nil
        table = nil
    }

    /// The panel is a non-activating window, so it never becomes key and cannot
    /// receive key events itself. A local monitor is how it reads the keyboard
    /// without stealing focus from Finder, which must stay frontmost for the
    /// paste to land in the right place.
    private func installKeyMonitor() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: NSEvent) {
        guard let table else { return }
        switch event.keyCode {
        case 53: // Escape
            hide()
        case 36, 76: // Return, Enter
            commitSelection()
        case 125: // Down
            let next = min(table.selectedRow + 1, entries.count - 1)
            table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            table.scrollRowToVisible(next)
        case 126: // Up
            let previous = max(table.selectedRow - 1, 0)
            table.selectRowIndexes(IndexSet(integer: previous), byExtendingSelection: false)
            table.scrollRowToVisible(previous)
        case 18...26: // 1 through 9
            let index = Int(event.keyCode) - 18
            guard index < entries.count else { return }
            onPick(entries[index].id)
            hide()
        default:
            break
        }
    }

    private func commitSelection() {
        guard let table, table.selectedRow >= 0, table.selectedRow < entries.count else { return }
        let id = entries[table.selectedRow].id
        hide()
        onPick(id)
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = entries[row]
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 38))

        let number = NSTextField(labelWithString: row < 9 ? "\(row + 1)" : "")
        number.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        number.textColor = .tertiaryLabelColor
        number.frame = NSRect(x: 14, y: 11, width: 16, height: 16)
        cell.addSubview(number)

        let name = NSTextField(labelWithString: entry.displayName)
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.lineBreakMode = .byTruncatingMiddle
        name.frame = NSRect(x: 36, y: 19, width: tableView.bounds.width - 52, height: 16)
        cell.addSubview(name)

        let path = NSTextField(labelWithString: entry.subtitle)
        path.font = .systemFont(ofSize: 10)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingHead
        path.frame = NSRect(x: 36, y: 4, width: tableView.bounds.width - 52, height: 14)
        cell.addSubview(path)

        return cell
    }
}
```

- [ ] **Step 2: Handle the new decision in `HotkeyMonitor.swift`**

`onShowHistory` and the `.showHistory` switch case already exist — they were added
right after Task 3 so the package would keep building. Nothing to do here.

- [ ] **Step 3: Wire it in `main.swift`**

Add the property:
```swift
    private lazy var historyPanel = HistoryPanel { [weak self] id in
        self?.pasteFromHistory(entryID: id)
    }
```

Replace the placeholder `historyEnabled: false` in `currentContext()` with the real
condition (leave the fallback `Context` in the monitor's closure at `false`):
```swift
            historyEnabled: Entitlements.hasPro && !historyStore.history.entries.isEmpty
```

Wire the monitor, next to `monitor.onPaste = ...`:
```swift
        monitor.onShowHistory = { [weak self] in
            guard let self else { return }
            self.historyPanel.show(entries: self.historyStore.history.entries)
        }
```

- [ ] **Step 4: Build and check by hand**

Run: `pkill -x CutX; ./scripts/build-app.sh && ./scripts/test.sh 2>&1 | grep "Test run with" && open dist/CutX.app`

Expected, with at least two things cut previously:
- `⌥⌘V` in Finder opens a panel listing recent cuts, newest first, the first row selected.
- Arrow keys move the selection; `Return` pastes it into the current folder; `Escape` dismisses.
- Pressing `2` pastes the second entry directly.
- `⌥⌘V` with an empty history does nothing special — Finder's own Move Item Here still runs.
- `⌘Z` after a history paste undoes the move.

- [ ] **Step 5: Commit**

```bash
git add Sources/CutX
git commit -m "feat: add the Option-Command-V history panel

Keyboard-driven: numbers jump, arrows move, Return pastes, Escape
dismisses. A non-activating panel with a global key monitor, so Finder
stays frontmost and the paste lands where the user is looking.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Privacy — say what is now stored

The history writes file paths to disk. The policy currently says CutX "collects nothing" and "stores nothing", which stays true for transmission and becomes **false for storage**. Apple compares the policy against behaviour, and a stale claim is a rejection waiting to happen. This task ships in the same release as the feature, not after it.

**Files:**
- Modify: `PRIVACY.md`, `site/cutx/privacy/index.html`, `README.md`

- [ ] **Step 1: Update `PRIVACY.md`**

Replace the `**CutX collects nothing.**` line with:
```markdown
**CutX sends nothing anywhere.** It makes no network connections at all. The only
thing it stores is a list of what you recently cut, on your Mac, so you can paste it
again later — and you can clear that at any time.
```

Add, after the "What CutX does on your Mac" list:
```markdown
- **Remembers what you cut.** The file paths of your recent cuts (up to 20) are
  stored in `~/Library/Application Support/CutX/history.json` so the list survives a
  restart. The paths never leave your Mac, the contents of the files are never read,
  and "Clear history" in the menu removes the file's contents immediately.
```

- [ ] **Step 2: Mirror the change in `site/cutx/privacy/index.html`**

Replace the contents of the `<p class="big">` element with:
```html
CutX sends nothing anywhere.
```

Add this list item to the "What CutX does on your Mac" list:
```html
  <li><b>Remembers what you cut.</b> The paths of your recent cuts (up to 20) are stored
      in <code>~/Library/Application Support/CutX/history.json</code>, so the list survives a
      restart. They never leave your Mac, the contents of your files are never read, and
      "Clear history" removes them immediately.</li>
```

- [ ] **Step 3: Note the feature in `README.md`**

Add to the settings table, after the Sounds row:
```markdown
| **Recent** | The last 20 things you cut, re-pasteable from the menu or with <kbd>⌥⌘V</kbd> |
```

- [ ] **Step 4: Verify no stale claim remains**

```bash
grep -rniE "collects nothing|stores nothing" README.md PRIVACY.md site/ || echo "no stale claims"
```
Expected: `no stale claims`.

- [ ] **Step 5: Commit**

```bash
git add README.md PRIVACY.md site
git commit -m "docs: the privacy policy now says what history stores

Cut history persists file paths, so 'collects nothing' was about to
become false for storage. It stays true for transmission: nothing is sent
anywhere, and the history can be cleared from the menu.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Extend the test checklists

**Files:**
- Modify: `docs/manual-testing.md`, `scripts/integration-test.sh`

- [ ] **Step 1: Add the automated case to `scripts/integration-test.sh`**

Insert before the `echo` that prints RESULTS:
```bash
echo "== 8. history keeps working after the pasteboard moves on"
finder_open "$SRC"; finder_select "$SRC/A.txt"; key x "command down"
pb_clear
finder_open "$DST"
# Paste from history via the menu is not scriptable; this checks the weaker but
# still meaningful claim: a plain paste after the pasteboard was cleared does not
# move the file, so history is the only path that could.
key v "command down"; sleep 0.8
if [[ -f "$SRC/A.txt" && ! -f "$DST/A.txt" ]]; then say_result "cleared pasteboard blocks a plain paste" 0
else say_result "cleared pasteboard blocks a plain paste" 1 "A moved without a valid pasteboard"; fi
```

- [ ] **Step 2: Add the manual cases to `docs/manual-testing.md`**

Add a new section before `## Permissions`:
```markdown
## Cut history

- [ ] Cut three different files in turn. Right-click the menu-bar icon: **Recent**
      lists all three, newest first.
- [ ] Pick the oldest from the Recent submenu while a different folder is open — it
      moves there.
- [ ] `⌘Z` after that — Finder undoes it, proving Finder performed the move.
- [ ] `⌥⌘V` in Finder opens the panel with the first row selected. Arrows move,
      `Return` pastes, `Escape` dismisses.
- [ ] Press `2` in the panel — the second entry pastes directly.
- [ ] Cut something, copy text in TextEdit, then paste an old entry from history —
      it still moves. History does not depend on the pasteboard surviving.
- [ ] Quit and relaunch — the history is still there.
- [ ] "Clear history" empties the list, and
      `~/Library/Application Support/CutX/history.json` reflects it.
- [ ] `⌥⌘V` with an empty history does nothing special: Finder's own Move Item Here
      runs as usual.
- [ ] Paste the same entry twice into two different folders — after the first paste
      the entry points at the new location, so the second paste moves it on from
      there.
```

- [ ] **Step 3: Run both**

Run: `./scripts/integration-test.sh 2>&1 | sed -n '/RESULTS/,$p'`
Expected: all cases pass, including the new one.

- [ ] **Step 4: Commit**

```bash
git add docs/manual-testing.md scripts/integration-test.sh
git commit -m "test: cover cut history in both checklists

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```
