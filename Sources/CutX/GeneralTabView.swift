import AppKit
import CutXCore

final class GeneralTabView: NSView {
    private let preferences: Preferences
    private let banner = NSTextField(labelWithString: "")
    private let checklist: PermissionChecklistView
    private let animation = SettingsAnimationView(
        frame: NSRect(x: 30, y: 24, width: 400, height: 128)
    )
    private let hint = NSTextField(labelWithString: "Find CutX in the list and switch it on:")
    private var toggles: [(NSButton, () -> Bool)] = []
    private var referenceViews: [NSView] = []
    /// The two key labels that gain a "(⌃X)" alternative when that setting is on.
    private var referenceKeyLabels: [(field: NSTextField, primary: String, alternate: String)] = []

    init(preferences: Preferences) {
        self.preferences = preferences
        self.checklist = PermissionChecklistView { permission in
            if permission == .accessibility {
                PermissionsCoordinator.requestAccessibilityPrompt()
            }
            permission.openSettings()
        }
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 400))
        build()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        banner.font = .systemFont(ofSize: 14, weight: .semibold)
        banner.frame = NSRect(x: 30, y: 356, width: 400, height: 22)
        addSubview(banner)

        checklist.frame = NSRect(x: 30, y: 224, width: 420, height: 118)
        addSubview(checklist)

        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 30, y: 200, width: 400, height: 16)
        addSubview(hint)

        addSubview(animation)

        // The behavior toggles sit where the permission block is when everything is
        // granted, so a healthy install shows settings rather than a wall of ✓.
        var y: CGFloat = 300
        addToggle("Also use ⌃X", y: y,
                  get: { [weak self] in self?.preferences.controlHotkeys ?? false },
                  set: { [weak self] in self?.preferences.controlHotkeys = $0 })
        y -= 30
        addToggle("Show cut indicator", y: y,
                  get: { [weak self] in self?.preferences.showIndicator ?? false },
                  set: { [weak self] in self?.preferences.showIndicator = $0 })
        y -= 30
        addToggle("Launch at login", y: y,
                  get: { LaunchAtLogin.isEnabled },
                  set: { [weak self] wanted in
                      // Only record it if the system accepted, so the checkbox never
                      // claims something that did not happen.
                      if LaunchAtLogin.set(wanted) {
                          self?.preferences.launchAtLogin = wanted
                      }
                  })

        buildQuickReference(below: y - 24)
    }

    /// Fills the space the permission block leaves behind once everything is
    /// granted. The ⌘Z line is the one that matters: most people will not guess
    /// that undo works, and knowing it does is what makes a tool that moves your
    /// files feel safe to try.
    private func buildQuickReference(below top: CGFloat) {
        let rule = NSBox(frame: NSRect(x: 30, y: top, width: 400, height: 1))
        rule.boxType = .separator
        addSubview(rule)
        referenceViews.append(rule)

        let heading = NSTextField(labelWithString: "HOW TO USE")
        heading.font = .systemFont(ofSize: 10, weight: .semibold)
        heading.textColor = .tertiaryLabelColor
        heading.frame = NSRect(x: 30, y: top - 26, width: 200, height: 14)
        addSubview(heading)
        referenceViews.append(heading)

        let rows = [
            ("⌘X", "⌃X", "Cut the selected files in Finder"),
            ("⌘V", "⌃V", "Move them here"),
            ("⌘Z", "", "Undo — it's Finder's own undo"),
        ]

        var rowY = top - 54
        for (primary, alternate, explanation) in rows {
            let key = NSTextField(labelWithString: primary)
            key.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            // Left-aligned so ⌘X, ⌘V and ⌘Z all start at the same point; right
            // alignment leaves ⌘Z stranded once the others gain "(⌃X)".
            key.alignment = .natural
            key.frame = NSRect(x: 44, y: rowY, width: 84, height: 18)
            addSubview(key)
            referenceViews.append(key)
            if !alternate.isEmpty {
                referenceKeyLabels.append((key, primary, alternate))
            }

            let text = NSTextField(labelWithString: explanation)
            text.font = .systemFont(ofSize: 12)
            text.textColor = .secondaryLabelColor
            text.frame = NSRect(x: 126, y: rowY, width: 300, height: 18)
            addSubview(text)
            referenceViews.append(text)

            rowY -= 26
        }
        updateReferenceKeys()
    }

    /// Shows the Control alternative only while it is actually active, so the
    /// reference always describes the keys that really work right now.
    private func updateReferenceKeys() {
        let alsoControl = preferences.controlHotkeys
        for entry in referenceKeyLabels {
            entry.field.stringValue = alsoControl
                ? "\(entry.primary)  (\(entry.alternate))"
                : entry.primary
        }
    }

    private func addToggle(
        _ title: String,
        y: CGFloat,
        get: @escaping () -> Bool,
        set: @escaping (Bool) -> Void
    ) {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.frame = NSRect(x: 30, y: y, width: 400, height: 22)
        button.state = get() ? .on : .off
        button.target = self
        button.action = #selector(toggleChanged(_:))
        button.tag = toggles.count
        addSubview(button)
        toggles.append((button, get))
        toggleSetters.append(set)
    }

    private var toggleSetters: [(Bool) -> Void] = []

    @objc private func toggleChanged(_ sender: NSButton) {
        guard sender.tag < toggleSetters.count else { return }
        toggleSetters[sender.tag](sender.state == .on)
        // Re-read the source of truth: the setter may have refused.
        sender.state = toggles[sender.tag].1() ? .on : .off
        updateReferenceKeys()
    }

    /// Called once a second while the window is open.
    func refresh() {
        let ready = PermissionsCoordinator.allGranted
        banner.stringValue = ready ? "✓  CutX is active"
                                   : "⚠︎  Setup needed — CutX is not active"
        banner.textColor = ready ? .systemGreen : .systemOrange

        checklist.isHidden = ready
        hint.isHidden = ready
        animation.isHidden = ready
        if ready { animation.stop() } else { checklist.refresh() }

        for (button, get) in toggles {
            button.isHidden = !ready
            button.state = get() ? .on : .off
        }
        for view in referenceViews { view.isHidden = !ready }
        updateReferenceKeys()
    }

    func startAnimating() {
        if !PermissionsCoordinator.allGranted { animation.start() }
    }

    func stopAnimating() {
        animation.stop()
    }
}
