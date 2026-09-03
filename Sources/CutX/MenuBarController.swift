import AppKit
import CutXCore

/// The status-bar item. It shows current state and offers the two actions a menu is
/// actually good for; everything configurable lives in the main window.
final class MenuBarController {
    private let statusItem: NSStatusItem

    var onClear: () -> Void = {}
    var onOpenWindow: () -> Void = {}

    private var names: [String] = []

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(buttonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        rebuild()
    }

    func update(names: [String]) {
        self.names = names
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
            let idle = NSMenuItem(title: "Nothing cut", action: nil, keyEquivalent: "")
            idle.isEnabled = false
            menu.addItem(idle)
        } else {
            let noun = names.count == 1 ? "item" : "items"
            let header = NSMenuItem(title: "\(names.count) \(noun) cut", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            let preview = NSMenuItem(
                title: names.prefix(3).joined(separator: ", ") + (names.count > 3 ? ", …" : ""),
                action: nil,
                keyEquivalent: ""
            )
            preview.isEnabled = false
            menu.addItem(preview)

            menu.addItem(item("Clear", #selector(clearTapped)))
        }

        menu.addItem(.separator())
        menu.addItem(item("Open CutX", #selector(openTapped)))
        menu.addItem(item("Buy me a coffee  ☕", #selector(coffeeTapped)))
        menu.addItem(NSMenuItem(
            title: "Quit CutX",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    @objc private func clearTapped() { onClear() }

    @objc private func openTapped() { onOpenWindow() }

    @objc private func coffeeTapped() {
        NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/ahmedhelal")!)
    }
}
