import AppKit
import CutXCore

/// The single window. CutX still launches without it — this opens on demand, and
/// automatically when a permission is missing, since an inert app that says nothing
/// looks broken.
final class MainWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let preferences: Preferences
    private let player: SoundPlayer
    private var general: GeneralTabView?
    private var refreshTimer: Timer?

    init(preferences: Preferences, player: SoundPlayer) {
        self.preferences = preferences
        self.player = player
    }

    func show() {
        if let window {
            general?.refresh()
            general?.startAnimating()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            startRefreshing()
            return
        }

        let tabs = NSTabView(frame: NSRect(x: 0, y: 0, width: 460, height: 400))
        tabs.tabViewType = .topTabsBezelBorder

        let general = GeneralTabView(preferences: preferences)
        general.onLanguageChanged = { [weak self] in self?.rebuildForNewLanguage() }
        self.general = general

        for (key, view) in [
            ("tab.general", general as NSView),
            ("tab.sounds", SoundsTabView(preferences: preferences, player: player)),
            ("tab.about", AboutTabView()),
        ] {
            let item = NSTabViewItem(identifier: key)
            item.label = T(key)
            item.view = view
            tabs.addTabViewItem(item)
        }

        L10n.applyDirection(to: tabs)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 432),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = T("window.title")
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = tabs
        if let content = window.contentView { L10n.applyDirection(to: content) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        general.startAnimating()
        startRefreshing()
    }

    /// Rebuilding beats walking the tree re-setting every string, and at this size
    /// it is instant.
    private func rebuildForNewLanguage() {
        L10n.resolve(preferences.language)

        refreshTimer?.invalidate()
        refreshTimer = nil
        general?.stopAnimating()
        general = nil

        if let window {
            window.delegate = nil
            window.orderOut(nil)
        }
        window = nil

        show()
    }

    /// Permission state is polled rather than observed: macOS sends no notification
    /// when a TCC toggle flips, and a stale checklist is worse than none.
    private func startRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            self?.general?.refresh()
        }
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
        general?.stopAnimating()
    }
}
