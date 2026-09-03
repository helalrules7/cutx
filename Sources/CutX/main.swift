import AppKit
import CutXCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuBar = MenuBarController(preferences: preferences)
        menuBar.onClear = { [weak self] in self?.clearCut() }
        self.menuBar = menuBar
    }

    private func clearCut() {
        menuBar?.update(names: [])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
