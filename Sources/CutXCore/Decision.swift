import Foundation

public enum Decision: Equatable {
    /// Let the event reach whatever app is frontmost, untouched.
    case passThrough
    /// Suppress the event; forward ⌘C to Finder and arm state.
    case cut
    /// Suppress the event; forward ⌥⌘V to Finder and clear state.
    case paste
}

public enum KeyCode {
    public static let x: UInt16 = 7  // kVK_ANSI_X
    public static let v: UInt16 = 9  // kVK_ANSI_V
}

public struct KeyEvent: Equatable, Sendable {
    public let keyCode: UInt16
    public let command: Bool
    public let control: Bool
    public let shift: Bool
    public let option: Bool

    public init(keyCode: UInt16, command: Bool, control: Bool, shift: Bool, option: Bool) {
        self.keyCode = keyCode
        self.command = command
        self.control = control
        self.shift = shift
        self.option = option
    }
}

public struct Context: Equatable, Sendable {
    public let finderFrontmost: Bool
    public let hasSelection: Bool
    public let isArmed: Bool
    public let pasteboardIntact: Bool
    public let controlHotkeysEnabled: Bool

    public init(
        finderFrontmost: Bool,
        hasSelection: Bool,
        isArmed: Bool,
        pasteboardIntact: Bool,
        controlHotkeysEnabled: Bool
    ) {
        self.finderFrontmost = finderFrontmost
        self.hasSelection = hasSelection
        self.isArmed = isArmed
        self.pasteboardIntact = pasteboardIntact
        self.controlHotkeysEnabled = controlHotkeysEnabled
    }
}

/// Classifies a keystroke. When anything is uncertain the answer is `.passThrough`:
/// a key that behaves normally is always better than a key that surprises the user.
public func decide(event: KeyEvent, context: Context) -> Decision {
    // Any extra modifier means a different shortcut. Never claim it.
    guard !event.shift, !event.option else { return .passThrough }

    // Exactly one of Command / Control, never both.
    if event.command, event.control { return .passThrough }
    if event.command {
        // ⌘X / ⌘V — always active.
    } else if event.control {
        guard context.controlHotkeysEnabled else { return .passThrough }
    } else {
        return .passThrough
    }

    guard context.finderFrontmost else { return .passThrough }

    switch event.keyCode {
    case KeyCode.x:
        return context.hasSelection ? .cut : .passThrough
    case KeyCode.v:
        return (context.isArmed && context.pasteboardIntact) ? .paste : .passThrough
    default:
        return .passThrough
    }
}
