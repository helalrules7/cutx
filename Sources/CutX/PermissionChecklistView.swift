import AppKit

/// One row per permission showing its real state. `refresh()` runs on a timer while
/// the window is open, so a row flips to ✓ the moment the user grants it — without
/// relaunching, and without having to guess whether it worked.
final class PermissionChecklistView: NSView {
    private struct Row {
        let permission: Permission
        let mark: NSTextField
        let button: NSButton
    }

    private var rows: [Row] = []
    private let onOpenSettings: (Permission) -> Void
    private let column = NSStackView()

    init(onOpenSettings: @escaping (Permission) -> Void) {
        self.onOpenSettings = onOpenSettings
        super.init(frame: .zero)
        buildRows()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildRows() {
        column.translatesAutoresizingMaskIntoConstraints = false
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 16
        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for (index, permission) in Permission.allCases.enumerated() {
            let mark = NSTextField(labelWithString: "○")
            mark.font = .systemFont(ofSize: 15, weight: .bold)
            mark.alignment = .natural
            mark.translatesAutoresizingMaskIntoConstraints = false
            mark.setContentHuggingPriority(.required, for: .horizontal)

            let title = NSTextField(labelWithString: permission.title)
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            title.alignment = .natural
            title.translatesAutoresizingMaskIntoConstraints = false

            let detail = NSTextField(wrappingLabelWithString: permission.detail)
            detail.font = .systemFont(ofSize: 11)
            detail.textColor = .secondaryLabelColor
            detail.alignment = .natural
            detail.translatesAutoresizingMaskIntoConstraints = false
            detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let text = NSStackView(views: [title, detail])
            text.translatesAutoresizingMaskIntoConstraints = false
            text.orientation = .vertical
            text.alignment = .leading
            text.spacing = 2

            let button = NSButton(title: T("permission.open"), target: self, action: #selector(openTapped(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)

            let row = NSStackView(views: [mark, text, button])
            row.translatesAutoresizingMaskIntoConstraints = false
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 8
            row.setHuggingPriority(.defaultLow, for: .horizontal)

            column.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            ])

            rows.append(Row(permission: permission, mark: mark, button: button))
        }
    }

    func refresh() {
        for row in rows {
            let granted = row.permission.isGranted
            row.mark.stringValue = granted ? "✓" : "✗"
            row.mark.textColor = granted ? .systemGreen : .systemRed
            row.button.isHidden = granted
        }
    }

    @objc private func openTapped(_ sender: NSButton) {
        guard sender.tag < Permission.allCases.count else { return }
        onOpenSettings(Permission.allCases[sender.tag])
    }
}
