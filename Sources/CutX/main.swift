import AppKit
import CutXCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var menuBar: MenuBarController?
    private lazy var sounds = SoundPlayer(preferences: preferences)
    private lazy var hud = CutHUD(preferences: preferences)
    private var monitor: HotkeyMonitor?
    private lazy var mainWindow = MainWindow(preferences: preferences, player: sounds)

    private var state = CutState()
    private let historyStore = HistoryStore()
    private var finderFrontmost = false
    private var pasteboardWatcher: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Resolved before anything is built: every label reads from it.
        L10n.resolve(preferences.language)

        let menuBar = MenuBarController()
        menuBar.onClear = { [weak self] in self?.clearCut() }
        menuBar.onOpenWindow = { [weak self] in self?.mainWindow.show() }
        menuBar.onPasteHistory = { [weak self] id in self?.pasteFromHistory(entryID: id) }
        menuBar.onClearHistory = { [weak self] in
            self?.historyStore.history.clear()
            self?.refreshMenuBar()
        }
        self.menuBar = menuBar

        observeFrontmostApp()
        watchPasteboard()

        let monitor = HotkeyMonitor(contextProvider: { [weak self] in
            self?.currentContext() ?? Context(
                finderFrontmost: false,
                hasSelection: false,
                isArmed: false,
                pasteboardIntact: false,
                controlHotkeysEnabled: false,
                historyEnabled: false
            )
        })
        monitor.onCut = { [weak self] in self?.performCut() }
        monitor.onPaste = { [weak self] in self?.performPaste() }
        if !monitor.start() {
            // Inert without Accessibility. Saying nothing here is what makes users
            // conclude the app is broken and delete it.
            mainWindow.show()
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                guard PermissionsCoordinator.allGranted else { return }
                timer.invalidate()
                _ = monitor.start()
            }
        }
        self.monitor = monitor

        preferences.launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Context

    private func currentContext() -> Context {
        Context(
            finderFrontmost: finderFrontmost,
            // Finder cannot be asked what is selected without Apple Events, which
            // the sandbox forbids. So the cut proceeds whenever Finder is frontmost,
            // and performCut() confirms a real selection afterwards by checking
            // that Finder actually put file URLs on the pasteboard.
            hasSelection: true,
            isArmed: state.isArmed,
            pasteboardIntact: state.isIntact(
                currentChangeCount: NSPasteboard.general.changeCount
            ),
            controlHotkeysEnabled: preferences.controlHotkeys,
            historyEnabled: false
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
        }
        finderFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            == FinderBridge.bundleIdentifier
    }


    /// The moment anything else writes to the pasteboard, the cut is void — the
    /// paste path already refuses to act on it, but the badge and menu must say so
    /// too, or the user sees "1 item cut" for something that can no longer move.
    /// NSPasteboard posts no notification, so this reads one integer twice a second.
    private func watchPasteboard() {
        pasteboardWatcher = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            guard let self, self.state.isArmed else { return }
            if !self.state.isIntact(currentChangeCount: NSPasteboard.general.changeCount) {
                self.state.clear()
                self.refreshMenuBar()
            }
        }
    }

    // MARK: - Actions

    private func performCut() {
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        FinderBridge.sendCopy()
        awaitFinderCopy(since: before, deadline: Date().addingTimeInterval(1.0))
    }

    /// Finder writes to the pasteboard some time after the keystroke — usually
    /// within a few tens of milliseconds, but not always. A fixed delay is wrong
    /// in both directions: too short and a busy Finder makes the cut silently
    /// fail, too long and the indicator lags. So poll the changeCount every 50 ms
    /// until it moves or a second has passed. A pasteboard that never changes
    /// means nothing was selected; one that changes to non-file content (text from
    /// a rename field) means this was not a file cut. Neither arms.
    private func awaitFinderCopy(since before: Int, deadline: Date) {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != before {
            let urls = FinderBridge.pasteboardFileURLs()
            guard !urls.isEmpty else { return }
            state.arm(items: urls, changeCount: pasteboard.changeCount)
            self.historyStore.history.record(urls)
            refreshMenuBar()
            sounds.playCut()
            hud.show(count: urls.count)
            return
        }
        guard Date() < deadline else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.awaitFinderCopy(since: before, deadline: deadline)
        }
    }

    private func performPaste() {
        // Remember what is about to move and where it is going, so the history
        // entry can be re-pointed at the new location after Finder is done.
        let moved = state.items
        let destination = FinderBridge.frontmostFinderDirectory()

        FinderBridge.sendMoveItemHere()
        state.clear()
        refreshMenuBar()
        sounds.playPaste()

        guard let destination,
              let entry = historyStore.history.entries.first(where: { $0.urls == moved })
        else { return }
        historyStore.history.updatePaths(
            id: entry.id,
            to: moved.map { destination.appendingPathComponent($0.lastPathComponent) }
        )
    }

    /// Pastes an entry the user picked from history. The pasteboard no longer
    /// holds it, so CutX writes it back before asking Finder to move.
    func pasteFromHistory(entryID: UUID) {
        guard let entry = historyStore.history.entries.first(where: { $0.id == entryID }) else { return }
        let changeCount = FinderBridge.writeToPasteboard(entry.urls)
        state.arm(items: entry.urls, changeCount: changeCount)
        refreshMenuBar()
        performPaste()
    }

    private func clearCut() {
        // Clearing means the whole operation is cancelled, so the files CutX put
        // on the pasteboard go with it — otherwise ⌘V afterwards still pastes a
        // copy of something the user just cancelled.
        //
        // Only when the pasteboard is still the one we armed: anything written
        // since belongs to another app, and emptying it would destroy their work.
        if state.isIntact(currentChangeCount: NSPasteboard.general.changeCount) {
            NSPasteboard.general.clearContents()
        }
        state.clear()
        refreshMenuBar()
    }

    private func refreshMenuBar() {
        menuBar?.update(names: state.displayNames, history: historyStore.history.entries)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
