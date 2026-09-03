import AppKit
import CutXCore

/// Owns the status-bar item and its menu. Knows nothing about hotkeys or Finder —
/// it renders state it is handed and reports user intent through closures.
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let preferences: Preferences

    var onClear: () -> Void = {}
    var onPreferenceChanged: () -> Void = {}
    var onPreviewSound: (String) -> Void = { _ in }

    private var names: [String] = []

    init(preferences: Preferences) {
        self.preferences = preferences
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuild()
    }

    /// `names` is the list of items currently marked; empty means idle.
    func update(names: [String]) {
        self.names = names
        rebuild()
    }

    private func rebuild() {
        if let button = statusItem.button {
            let symbol = names.isEmpty ? "scissors" : "scissors.circle.fill"
            button.image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: "CutX"
            )
            button.title = names.isEmpty ? "" : " \(names.count)"
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if names.isEmpty {
            let idle = NSMenuItem(title: "Nothing cut", action: nil, keyEquivalent: "")
            idle.isEnabled = false
            menu.addItem(idle)
        } else {
            let noun = names.count == 1 ? "item" : "items"
            let header = NSMenuItem(
                title: "\(names.count) \(noun) cut",
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)

            let preview = NSMenuItem(
                title: names.prefix(3).joined(separator: ", ")
                    + (names.count > 3 ? ", …" : ""),
                action: nil,
                keyEquivalent: ""
            )
            preview.isEnabled = false
            menu.addItem(preview)

            menu.addItem(
                item(title: "Clear", action: #selector(clearTapped), target: self)
            )
        }

        menu.addItem(.separator())
        menu.addItem(toggle("Play sound", #selector(togglePlaySound), preferences.playSound))
        menu.addItem(cutSoundMenuItem())
        menu.addItem(toggle("Show cut indicator", #selector(toggleShowIndicator), preferences.showIndicator))
        menu.addItem(toggle("Also use ⌃X", #selector(toggleControlHotkeys), preferences.controlHotkeys))
        menu.addItem(toggle("Launch at login", #selector(toggleLaunchAtLogin), preferences.launchAtLogin))

        menu.addItem(.separator())
        menu.addItem(item(title: "Buy me a coffee  ☕", action: #selector(buyCoffee), target: self))
        menu.addItem(item(title: "About CutX", action: #selector(about), target: self))

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit CutX",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    /// A submenu of the shipped cut sounds. Picking one plays it straight away —
    /// these are chosen by ear, and making the user close the menu, cut a file,
    /// and reopen the menu to compare two options would be absurd.
    private func cutSoundMenuItem() -> NSMenuItem {
        let submenu = NSMenu()
        for sound in CutSound.all {
            let entry = NSMenuItem(
                title: sound.label,
                action: #selector(selectCutSound(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.representedObject = sound.id
            entry.state = (sound.id == preferences.cutSound) ? .on : .off
            submenu.addItem(entry)
        }

        let parent = NSMenuItem(title: "Cut sound", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        parent.isEnabled = preferences.playSound
        return parent
    }

    @objc private func selectCutSound(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        preferences.cutSound = id
        onPreviewSound(id)
        changed()
    }

    private func item(title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = target
        return menuItem
    }

    private func toggle(_ title: String, _ action: Selector, _ on: Bool) -> NSMenuItem {
        let menuItem = item(title: title, action: action, target: self)
        menuItem.state = on ? .on : .off
        return menuItem
    }

    @objc private func clearTapped() { onClear() }

    @objc private func togglePlaySound() {
        preferences.playSound.toggle()
        changed()
    }

    @objc private func toggleShowIndicator() {
        preferences.showIndicator.toggle()
        changed()
    }

    @objc private func toggleControlHotkeys() {
        preferences.controlHotkeys.toggle()
        changed()
    }

    @objc private func toggleLaunchAtLogin() {
        preferences.launchAtLogin.toggle()
        changed()
    }

    private func changed() {
        rebuild()
        onPreferenceChanged()
    }

    @objc private func buyCoffee() {
        NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/ahmedhelal")!)
    }

    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "CutX"
        alert.informativeText = """
            Cut and paste files in Finder the way you expect.

            Press ⌘X on a file or folder, then ⌘V where you want it. \
            CutX hands the move to Finder itself, so undo, progress, and \
            conflict handling all work normally.

            Free and open source. MIT licensed.
            """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
