import AppKit
import CutXCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var menuBar: MenuBarController?
    private var monitor: HotkeyMonitor?

    private var state = CutState()
    private var finderFrontmost = false
    private var selectionCount = 0
    private var selectionTimer: Timer?
    private var selectionQueryInFlight = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuBar = MenuBarController(preferences: preferences)
        menuBar.onClear = { [weak self] in self?.clearCut() }
        self.menuBar = menuBar

        FinderBridge.prepare()
        observeFrontmostApp()
        startSelectionPolling()

        let monitor = HotkeyMonitor(contextProvider: { [weak self] in
            self?.currentContext() ?? Context(
                finderFrontmost: false,
                hasSelection: false,
                isArmed: false,
                pasteboardIntact: false,
                controlHotkeysEnabled: false
            )
        })
        monitor.onCut = { [weak self] in self?.performCut() }
        monitor.onPaste = { [weak self] in self?.performPaste() }
        _ = monitor.start()
        self.monitor = monitor
    }

    // MARK: - Context

    private func currentContext() -> Context {
        Context(
            finderFrontmost: finderFrontmost,
            hasSelection: selectionCount > 0,
            isArmed: state.isArmed,
            pasteboardIntact: state.isIntact(
                currentChangeCount: NSPasteboard.general.changeCount
            ),
            controlHotkeysEnabled: preferences.controlHotkeys
        )
    }

    private func observeFrontmostApp() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            self?.finderFrontmost = app?.bundleIdentifier == FinderBridge.bundleIdentifier
            self?.refreshSelectionCount()
        }
        finderFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            == FinderBridge.bundleIdentifier
    }

    /// Finder has no selection-changed notification, so poll — but only while
    /// Finder is frontmost, which keeps this idle almost all the time.
    private func startSelectionPolling() {
        selectionTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) {
            [weak self] _ in
            self?.refreshSelectionCount()
        }
    }

    private func refreshSelectionCount() {
        guard finderFrontmost else {
            selectionCount = 0
            return
        }
        // Skip this tick if the previous round-trip has not come back yet, so a
        // slow Finder cannot make the polls pile up on each other.
        guard !selectionQueryInFlight else { return }
        selectionQueryInFlight = true
        FinderBridge.selectionCountAsync { [weak self] count in
            guard let self else { return }
            self.selectionQueryInFlight = false
            self.selectionCount = self.finderFrontmost ? count : 0
        }
    }

    // MARK: - Actions

    private func performCut() {
        let urls = FinderBridge.selectedURLs()
        guard !urls.isEmpty else { return }

        FinderBridge.sendCopy()

        // Give Finder a moment to actually write to the pasteboard before
        // recording the changeCount we will later verify against.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.state.arm(
                items: urls,
                changeCount: NSPasteboard.general.changeCount
            )
            self.menuBar?.update(names: self.state.displayNames)
        }
    }

    private func performPaste() {
        FinderBridge.sendMoveItemHere()
        state.clear()
        menuBar?.update(names: [])
    }

    private func clearCut() {
        state.clear()
        menuBar?.update(names: [])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
