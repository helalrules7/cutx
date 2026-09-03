import AppKit
import CutXCore

/// String lookup and layout direction for the whole interface.
///
/// `resolve()` is called once when the window is built rather than on every
/// lookup: switching language rebuilds the window anyway, and a per-lookup bundle
/// search would be wasted work on every label.
enum L10n {
    private(set) static var bundle: Bundle = .main
    private(set) static var isRightToLeft = false

    static func resolve(_ preference: Language) {
        let language = preference == .automatic ? systemLanguage() : preference

        if let path = Bundle.main.path(forResource: language.code, ofType: "lproj"),
           let localized = Bundle(path: path) {
            bundle = localized
        } else {
            bundle = .main
        }
        isRightToLeft = language.isRightToLeft
    }

    static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// The first system preference we actually ship, or English.
    private static func systemLanguage() -> Language {
        let shipped = Language.allCases.filter { $0 != .automatic }
        for preferred in Bundle.preferredLocalizations(
            from: shipped.map(\.code),
            forPreferences: Locale.preferredLanguages
        ) {
            if let match = shipped.first(where: { $0.code == preferred }) {
                return match
            }
        }
        return .english
    }

    /// Applies the resolved direction to a whole view tree.
    ///
    /// AppKit does NOT inherit `userInterfaceLayoutDirection` from a superview —
    /// every view resolves its own, defaulting to the app's launch localization.
    /// Setting it only on the root leaves every checkbox and stack view still
    /// laid out left to right, which is exactly the bug this recursion fixes.
    static func applyDirection(to view: NSView) {
        let direction: NSUserInterfaceLayoutDirection = isRightToLeft ? .rightToLeft : .leftToRight
        apply(direction, to: view)
    }

    private static func apply(_ direction: NSUserInterfaceLayoutDirection, to view: NSView) {
        view.userInterfaceLayoutDirection = direction

        // NSControl and NSStackView each carry their own copy of the property;
        // the NSView one does not reach them.
        if let control = view as? NSControl {
            control.userInterfaceLayoutDirection = direction
        }
        if let stack = view as? NSStackView {
            stack.userInterfaceLayoutDirection = direction
        }
        if let tabs = view as? NSTabView {
            for item in tabs.tabViewItems {
                if let content = item.view { apply(direction, to: content) }
            }
        }
        for subview in view.subviews {
            apply(direction, to: subview)
        }
    }
}

/// Shorthand used throughout the UI.
func T(_ key: String) -> String { L10n.string(key) }
