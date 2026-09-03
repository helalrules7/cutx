import AppKit
import CutXCore

/// All communication with Finder: reading the selection over Apple Events, and
/// posting the synthetic keystrokes that make Finder do the actual work.
///
/// Nothing here may be called from inside the event-tap callback — `NSAppleScript`
/// round-trips take tens of milliseconds and would stall system-wide keyboard input.
enum FinderBridge {
    static let bundleIdentifier = "com.apple.finder"

    /// Stamped into every event CutX posts, so the tap can recognize and skip its own.
    static let syntheticMarker: Int64 = 0x43_75_74_58  // "CutX"

    // MARK: - Reading the selection

    static func selectionCount() -> Int {
        let source = """
            tell application "Finder"
                return (count of (get selection)) as string
            end tell
            """
        guard let result = run(source) else { return 0 }
        return Int(result) ?? 0
    }

    static func selectedURLs() -> [URL] {
        let source = """
            tell application "Finder"
                set theSelection to (get selection)
                set thePaths to {}
                repeat with anItem in theSelection
                    set end of thePaths to POSIX path of (anItem as alias)
                end repeat
                set AppleScript's text item delimiters to linefeed
                return thePaths as text
            end tell
            """
        guard let result = run(source), !result.isEmpty else { return [] }
        return result
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }

    private static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if let error {
            NSLog("CutX: AppleScript failed: \(error)")
            return nil
        }
        return output.stringValue
    }

    // MARK: - Posting synthetic keystrokes

    /// Finder's Copy. Puts the selection on the pasteboard in the form
    /// Move Item Here expects.
    static func sendCopy() {
        post(keyCode: 8, flags: .maskCommand)  // kVK_ANSI_C
    }

    /// Finder's Edit ▸ Move Item Here (⌥⌘V). Finder performs the move itself,
    /// which is what gives us undo, progress, and conflict handling.
    static func sendMoveItemHere() {
        post(keyCode: KeyCode.v, flags: [.maskCommand, .maskAlternate])
    }

    private static func post(keyCode: UInt16, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        for event in [down, up] {
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            event.post(tap: .cghidEventTap)
        }
    }
}
