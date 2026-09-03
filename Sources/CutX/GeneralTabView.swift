import AppKit
import CutXCore

final class GeneralTabView: NSView {
    private let preferences: Preferences
    private let banner = NSTextField(labelWithString: "")
    private let checklist: PermissionChecklistView
    /// Constructed with an explicit size because its CALayers are laid out from
    /// `bounds` at init time; the size is pinned again below with constraints.
    private let animation = SettingsAnimationView(
        frame: NSRect(x: 0, y: 0, width: 400, height: 128)
    )
    private let hint = NSTextField(labelWithString: "")
    private var toggles: [(NSButton, () -> Bool)] = []
    private var referenceViews: [NSView] = []
    /// The two key labels that gain a "(⌃X)" alternative when that setting is on.
    private var referenceKeyLabels: [(field: NSTextField, primary: String, alternate: String)] = []

    /// The permission block and the settings block trade places: a healthy install
    /// shows settings rather than a wall of ✓.
    private let permissionBlock = NSStackView()
    private let settingsBlock = NSStackView()
    private let referenceBlock = NSStackView()
    private let languageRow = NSStackView()
    private let languagePopUp = NSPopUpButton()

    /// Called when the user picks a different language. `MainWindow` rebuilds.
    var onLanguageChanged: () -> Void = {}

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
        L10n.applyDirection(to: self)

        banner.font = .systemFont(ofSize: 14, weight: .semibold)
        banner.alignment = .natural
        banner.translatesAutoresizingMaskIntoConstraints = false

        buildPermissionBlock()
        buildSettingsBlock()
        buildLanguageRow()
        buildQuickReference()

        let column = NSStackView(
            views: [banner, permissionBlock, settingsBlock, languageRow, referenceBlock]
        )
        column.translatesAutoresizingMaskIntoConstraints = false
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 16
        addSubview(column)

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
            banner.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            banner.trailingAnchor.constraint(lessThanOrEqualTo: column.trailingAnchor),
            permissionBlock.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            permissionBlock.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            settingsBlock.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            settingsBlock.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            languageRow.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            languageRow.trailingAnchor.constraint(lessThanOrEqualTo: column.trailingAnchor),
            referenceBlock.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            referenceBlock.trailingAnchor.constraint(equalTo: column.trailingAnchor),
        ])
    }

    private func buildPermissionBlock() {
        checklist.translatesAutoresizingMaskIntoConstraints = false

        hint.stringValue = T("permission.hint")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .natural
        hint.translatesAutoresizingMaskIntoConstraints = false

        animation.translatesAutoresizingMaskIntoConstraints = false

        permissionBlock.translatesAutoresizingMaskIntoConstraints = false
        permissionBlock.orientation = .vertical
        permissionBlock.alignment = .leading
        permissionBlock.spacing = 10
        permissionBlock.addArrangedSubview(checklist)
        permissionBlock.addArrangedSubview(hint)
        permissionBlock.addArrangedSubview(animation)

        NSLayoutConstraint.activate([
            checklist.leadingAnchor.constraint(equalTo: permissionBlock.leadingAnchor),
            checklist.trailingAnchor.constraint(equalTo: permissionBlock.trailingAnchor),
            hint.leadingAnchor.constraint(equalTo: permissionBlock.leadingAnchor),
            animation.leadingAnchor.constraint(equalTo: permissionBlock.leadingAnchor),
            animation.widthAnchor.constraint(equalToConstant: 400),
            animation.heightAnchor.constraint(equalToConstant: 128),
        ])
    }

    private func buildSettingsBlock() {
        settingsBlock.translatesAutoresizingMaskIntoConstraints = false
        settingsBlock.orientation = .vertical
        settingsBlock.alignment = .leading
        settingsBlock.spacing = 8

        addToggle(T("general.alsoUseControl"),
                  get: { [weak self] in self?.preferences.controlHotkeys ?? false },
                  set: { [weak self] in self?.preferences.controlHotkeys = $0 })
        addToggle(T("general.showIndicator"),
                  get: { [weak self] in self?.preferences.showIndicator ?? false },
                  set: { [weak self] in self?.preferences.showIndicator = $0 })
        addToggle(T("general.launchAtLogin"),
                  get: { LaunchAtLogin.isEnabled },
                  set: { [weak self] wanted in
                      // Only record it if the system accepted, so the checkbox never
                      // claims something that did not happen.
                      if LaunchAtLogin.set(wanted) {
                          self?.preferences.launchAtLogin = wanted
                      }
                  })
    }

    private func buildLanguageRow() {
        let label = NSTextField(labelWithString: T("general.language"))
        label.font = .systemFont(ofSize: 12)
        label.alignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)

        languagePopUp.translatesAutoresizingMaskIntoConstraints = false
        languagePopUp.removeAllItems()
        languagePopUp.addItems(withTitles: Language.allCases.map(\.nativeName))
        if let index = Language.allCases.firstIndex(of: preferences.language) {
            languagePopUp.selectItem(at: index)
        }
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged(_:))

        languageRow.translatesAutoresizingMaskIntoConstraints = false
        languageRow.orientation = .horizontal
        languageRow.alignment = .centerY
        languageRow.spacing = 10
        languageRow.addArrangedSubview(label)
        languageRow.addArrangedSubview(languagePopUp)
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let languages = Language.allCases
        guard sender.indexOfSelectedItem < languages.count else { return }
        preferences.language = languages[sender.indexOfSelectedItem]
        onLanguageChanged()
    }

    /// Fills the space the permission block leaves behind once everything is
    /// granted. The ⌘Z line is the one that matters: most people will not guess
    /// that undo works, and knowing it does is what makes a tool that moves your
    /// files feel safe to try.
    private func buildQuickReference() {
        referenceBlock.translatesAutoresizingMaskIntoConstraints = false
        referenceBlock.orientation = .vertical
        referenceBlock.alignment = .leading
        referenceBlock.spacing = 8

        let rule = NSBox()
        rule.boxType = .separator
        rule.translatesAutoresizingMaskIntoConstraints = false
        referenceBlock.addArrangedSubview(rule)
        referenceViews.append(rule)
        NSLayoutConstraint.activate([
            rule.leadingAnchor.constraint(equalTo: referenceBlock.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: referenceBlock.trailingAnchor),
        ])

        let heading = NSTextField(labelWithString: T("general.howToUse"))
        heading.font = .systemFont(ofSize: 10, weight: .semibold)
        heading.textColor = .tertiaryLabelColor
        heading.alignment = .natural
        heading.translatesAutoresizingMaskIntoConstraints = false
        referenceBlock.addArrangedSubview(heading)
        referenceViews.append(heading)
        heading.leadingAnchor.constraint(equalTo: referenceBlock.leadingAnchor).isActive = true

        let rows = [
            ("⌘X", "⌃X", T("general.howTo.cut")),
            ("⌘V", "⌃V", T("general.howTo.paste")),
            ("⌘Z", "", T("general.howTo.undo")),
        ]

        var keyFields: [NSTextField] = []
        for (primary, alternate, explanation) in rows {
            let key = NSTextField(labelWithString: primary)
            key.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            // Natural alignment so ⌘X, ⌘V and ⌘Z all start at the same point, in
            // whichever direction the interface reads.
            key.alignment = .natural
            key.translatesAutoresizingMaskIntoConstraints = false
            key.setContentHuggingPriority(.defaultLow, for: .horizontal)
            keyFields.append(key)
            referenceViews.append(key)
            if !alternate.isEmpty {
                referenceKeyLabels.append((key, primary, alternate))
            }

            let text = NSTextField(labelWithString: explanation)
            text.font = .systemFont(ofSize: 12)
            text.textColor = .secondaryLabelColor
            text.alignment = .natural
            text.translatesAutoresizingMaskIntoConstraints = false
            referenceViews.append(text)

            let row = NSStackView(views: [key, text])
            row.translatesAutoresizingMaskIntoConstraints = false
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 12
            referenceBlock.addArrangedSubview(row)
            referenceViews.append(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: referenceBlock.leadingAnchor, constant: 14),
                row.trailingAnchor.constraint(lessThanOrEqualTo: referenceBlock.trailingAnchor),
            ])
        }

        // The key column stays a single column whatever it currently reads.
        if let first = keyFields.first {
            for field in keyFields.dropFirst() {
                field.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true
            }
            first.widthAnchor.constraint(greaterThanOrEqualToConstant: 84).isActive = true
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
        get: @escaping () -> Bool,
        set: @escaping (Bool) -> Void
    ) {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.state = get() ? .on : .off
        button.target = self
        button.action = #selector(toggleChanged(_:))
        button.tag = toggles.count
        settingsBlock.addArrangedSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: settingsBlock.leadingAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: settingsBlock.trailingAnchor),
        ])
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
        banner.stringValue = ready ? "✓  \(T("general.active"))"
                                   : "⚠︎  \(T("general.setupNeeded"))"
        banner.textColor = ready ? .systemGreen : .systemOrange

        permissionBlock.isHidden = ready
        checklist.isHidden = ready
        hint.isHidden = ready
        animation.isHidden = ready
        if ready { animation.stop() } else { checklist.refresh() }

        settingsBlock.isHidden = !ready
        referenceBlock.isHidden = !ready
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
