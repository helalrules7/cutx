import AppKit
import CutXCore

/// All communication with Finder: reading the selection over Apple Events, and
/// posting the synthetic keystrokes that make Finder do the actual work.
///
/// Nothing here may be called from inside the event-tap callback — `NSAppleScript`
/// round-trips take tens of milliseconds and would stall system-wide keyboard input.
///
/// `NSAppleScript` is not thread-safe, so every script runs on one dedicated
/// serial queue: created there, executed there, never concurrently. Callers reach
/// it through `runAsync` (off the main thread) or the blocking helpers below.
enum FinderBridge {
    static let bundleIdentifier = "com.apple.finder"

    /// Stamped into every event CutX posts, so the tap can recognize and skip its own.
    static let syntheticMarker: Int64 = 0x43_75_74_58  // "CutX"

    /// The one and only thread that ever touches NSAppleScript.
    private static let scriptQueue = DispatchQueue(label: "com.helalrules.CutX.applescript")

    /// Compiled once and reused. Recompiling identical source every 400 ms would
    /// be pure waste, and compilation is the slower half of a round-trip.
    private static var compiled: [String: NSAppleScript] = [:]

    // MARK: - Reading the selection

    static func selectionCount() -> Int {
        guard let result = run(selectionCountSource) else { return 0 }
        return Int(result) ?? 0
    }

    /// Non-blocking variant used by the 400 ms poll.
    static func selectionCountAsync(_ completion: @escaping (Int) -> Void) {
        runAsync(selectionCountSource) { completion(Int($0 ?? "") ?? 0) }
    }

    private static let selectionCountSource = """
        tell application "Finder"
            return (count of (get selection)) as string
        end tell
        """

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

    /// Runs `source` on the script queue and delivers the result on the main queue.
    /// Use this for anything on a timer — it never blocks the caller.
    static func runAsync(_ source: String, then completion: @escaping (String?) -> Void) {
        scriptQueue.async {
            let result = run(source)
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Blocks the caller until the script finishes. Only for the cut path, where
    /// the answer is needed before anything else can happen.
    private static func run(_ source: String) -> String? {
        if DispatchQueue.getSpecific(key: queueKey) == nil {
            return scriptQueue.sync { execute(source) }
        }
        return execute(source)
    }

    private static let queueKey = DispatchSpecificKey<Bool>()

    /// Must only ever be called on `scriptQueue`.
    private static func execute(_ source: String) -> String? {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return nil }
            compiled[source] = fresh
            script = fresh
        }

        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if let error {
            NSLog("CutX: AppleScript failed: \(error)")
            return nil
        }
        return output.stringValue
    }

    /// Called once at startup so `run` can tell whether it is already on the queue.
    static func prepare() {
        scriptQueue.setSpecific(key: queueKey, value: true)
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
