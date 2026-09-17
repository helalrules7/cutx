import AppKit
import CutXCore

/// The status-bar item. It shows current state and offers the two actions a menu is
/// actually good for; everything configurable lives in the main window.
final class MenuBarController {
    private let statusItem: NSStatusItem

    var onClear: () -> Void = {}
    var onOpenWindow: () -> Void = {}
    var onPasteHistory: (UUID) -> Void = { _ in }
    var onClearHistory: () -> Void = {}

    private var names: [String] = []
    private var history: [HistoryEntry] = []

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(buttonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        rebuild()
    }

    func update(names: [String], history: [HistoryEntry] = []) {
        self.names = names
        self.history = history
        rebuild()
    }

    private func rebuild() {
        if let button = statusItem.button {
            button.image = MenuBarIcon.image(open: names.isEmpty)
            button.title = names.isEmpty ? "" : " \(names.count)"
        }
    }

    /// Left click opens the window, right click shows the short menu. The menu is
    /// attached only for the duration of the click so the left-click action still runs.
    @objc private func buttonClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            let menu = buildMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onOpenWindow()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if names.isEmpty {
            let idle = NSMenuItem(title: T("menu.nothingCut"), action: nil, keyEquivalent: "")
            idle.isEnabled = false
            menu.addItem(idle)
        } else {
            let key = names.count == 1 ? "menu.itemCut" : "menu.itemsCut"
            let header = NSMenuItem(
                title: String(format: T(key), names.count),
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)

            let preview = NSMenuItem(
                title: names.prefix(3).joined(separator: ", ") + (names.count > 3 ? ", …" : ""),
                action: nil,
                keyEquivalent: ""
            )
            preview.isEnabled = false
            menu.addItem(preview)

            menu.addItem(item(T("menu.clear"), #selector(clearTapped)))
        }

        if Entitlements.hasPro {
            menu.addItem(.separator())
            menu.addItem(historyMenuItem())
        }

        menu.addItem(.separator())
        menu.addItem(item(T("menu.open"), #selector(openTapped)))
        // Omitted from App Store builds — see guideline 3.1.1.
        #if !APPSTORE
        menu.addItem(item("\(T("menu.coffee"))  ☕", #selector(coffeeTapped)))
        #endif
        menu.addItem(NSMenuItem(
            title: T("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

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
                    title: Self.label(for: entry),
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

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    /// "Report.pdf" alone, or "Report.pdf + 2 more" in whatever wording the
    /// current language uses. The count's phrasing is localised; the file name
    /// never is.
    static func label(for entry: HistoryEntry) -> String {
        guard entry.extraCount > 0 else { return entry.displayName }
        return String(format: T("history.more"), entry.displayName, entry.extraCount)
    }

    @objc private func historyPicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onPasteHistory(id)
    }

    @objc private func clearHistoryTapped() { onClearHistory() }

    @objc private func clearTapped() { onClear() }

    @objc private func openTapped() { onOpenWindow() }

    #if !APPSTORE
    @objc private func coffeeTapped() {
        NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/ahmedhelal")!)
    }
    #endif
}
