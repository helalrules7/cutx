import AppKit
import ApplicationServices
import CutXCore

/// Everything CutX does to Finder — which is only ever two synthetic keystrokes.
///
/// CutX used to ask Finder over Apple Events which items were selected. The App
/// Sandbox forbids that for Finder specifically (error -600, "Application isn't
/// running", even with the user's Automation consent), and Apple no longer grants
/// the temporary exception that used to allow it. So CutX no longer asks. It sends
/// Finder's own Copy, then reads back what Finder placed on the pasteboard. That
/// needs no Apple Events, no Automation permission, and no polling — and Finder
/// still performs every file operation.
enum FinderBridge {
    static let bundleIdentifier = "com.apple.finder"

    /// Stamped into every event CutX posts, so the tap can recognise and skip its own.
    static let syntheticMarker: Int64 = 0x43_75_74_58  // "CutX"

    /// The file URLs Finder put on the pasteboard with its own Copy command.
    /// Empty when the pasteboard holds anything else — text, an image, nothing —
    /// which is exactly when CutX must not arm.
    static func pasteboardFileURLs() -> [URL] {
        let objects = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return (objects as? [URL]) ?? []
    }

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
